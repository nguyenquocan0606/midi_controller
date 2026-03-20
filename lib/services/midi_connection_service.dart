import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../types/midi_control_type.dart';
import '../types/connection_state.dart';
import '../types/app_config.dart';
import '../constants/app_constants.dart';

/// Loại message từ server
enum ServerMessageType {
  connected,
  config,
  midiFeedback,
  osc,
  stateSync,
}

/// Server message wrapper
class ServerMessage {
  final ServerMessageType type;
  final MidiMessage? midiMessage;
  final AppConfig? config;
  final String? rawData;

  ServerMessage({
    required this.type,
    this.midiMessage,
    this.config,
    this.rawData,
  });
}

/// Service quản lý kết nối WebSocket đến PC server
/// Hỗ trợ auto-reconnect, gửi/nhận MIDI messages và config sync
class MidiConnectionService {
  WebSocketChannel? _channel;
  MidiConnectionStatus _status = MidiConnectionStatus.disconnected;
  ConnectionConfig _config = const ConnectionConfig();
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // Stream controllers
  final _statusController =
      StreamController<MidiConnectionStatus>.broadcast();
  final _messageController = StreamController<MidiMessage>.broadcast();
  final _configController = StreamController<AppConfig>.broadcast();

  // Throttle
  DateTime _lastSendTime = DateTime.now();

  /// Stream lắng nghe thay đổi trạng thái kết nối
  Stream<MidiConnectionStatus> get statusStream => _statusController.stream;

  /// Stream lắng nghe messages từ server (MIDI feedback)
  Stream<MidiMessage> get messageStream => _messageController.stream;

  /// Stream nhận config từ server
  Stream<AppConfig> get configStream => _configController.stream;

  /// Trạng thái kết nối hiện tại
  MidiConnectionStatus get status => _status;

  /// Config hiện tại
  ConnectionConfig get config => _config;

  /// Kết nối đến PC server
  Future<void> connect(ConnectionConfig config) async {
    _config = config;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  /// Thực hiện kết nối
  Future<void> _doConnect() async {
    if (_status == MidiConnectionStatus.connecting) return;

    _updateStatus(MidiConnectionStatus.connecting);

    try {
      final wsUrl = Uri.parse(_config.wsUrl);
      _channel = WebSocketChannel.connect(wsUrl);

      await _channel!.ready;

      _updateStatus(MidiConnectionStatus.connected);
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        (data) {
          _handleIncomingData(data.toString());
        },
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('🔌 WebSocket closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('❌ Connection failed: $e');
      _updateStatus(MidiConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  /// Xử lý data nhận từ server
  void _handleIncomingData(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'connected') {
        if (json.containsKey('config')) {
          final cfg = AppConfig.fromJson(json['config'] as Map<String, dynamic>);
          _configController.add(cfg);
          debugPrint('[CFG] Connected - received config');
        }
        return;
      }

      if (type == 'config') {
        if (json.containsKey('config')) {
          final cfg = AppConfig.fromJson(json['config'] as Map<String, dynamic>);
          _configController.add(cfg);
          debugPrint('[CFG] Config updated');
        }
        return;
      }

      if (type == 'osc') {
        // OSC message - forward as raw for now
        debugPrint('[OSC] ${json['address']}');
        return;
      }

      // Default: MIDI feedback message
      try {
        final msg = MidiMessage.fromJson(raw);
        _messageController.add(msg);
      } catch (e) {
        debugPrint('⚠️ Parse MIDI error: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Parse error: $e');
    }
  }

  /// Ngắt kết nối
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = AppConstants.maxReconnectAttempts;
    await _channel?.sink.close();
    _channel = null;
    _updateStatus(MidiConnectionStatus.disconnected);
  }

  /// Gửi MIDI message đến server
  void sendMessage(MidiMessage message) {
    if (_status != MidiConnectionStatus.connected || _channel == null) return;

    final now = DateTime.now();
    if (now.difference(_lastSendTime).inMilliseconds <
        AppConstants.messageThrottleMs) {
      return;
    }
    _lastSendTime = now;

    try {
      _channel!.sink.add(message.toJson());
    } catch (e) {
      debugPrint('❌ Send failed: $e');
    }
  }

  /// Gửi Control Change
  void sendCC(int channel, int cc, int value) {
    sendMessage(MidiMessage(
      type: MidiMessageType.controlChange,
      channel: channel,
      control: cc,
      value: value,
    ));
  }

  /// Gửi Note On
  void sendNoteOn(int channel, int note, int velocity) {
    sendMessage(MidiMessage(
      type: MidiMessageType.noteOn,
      channel: channel,
      control: note,
      value: velocity,
    ));
  }

  /// Gửi Note Off
  void sendNoteOff(int channel, int note) {
    sendMessage(MidiMessage(
      type: MidiMessageType.noteOff,
      channel: channel,
      control: note,
      value: 0,
    ));
  }

  /// Gửi OSC message đến server
  void sendOsc(String address, List<Object> args) {
    if (_status != MidiConnectionStatus.connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'oscSend',
        'address': address,
        'args': args,
      }));
    } catch (e) {
      debugPrint('❌ OSC send failed: $e');
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _updateStatus(MidiConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) {
      debugPrint('❌ Max reconnect attempts reached');
      _updateStatus(MidiConnectionStatus.error);
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    debugPrint(
        '🔄 Reconnecting in ${AppConstants.reconnectIntervalMs}ms '
        '(attempt $_reconnectAttempts/${AppConstants.maxReconnectAttempts})');

    _reconnectTimer = Timer(
      const Duration(milliseconds: AppConstants.reconnectIntervalMs),
      _doConnect,
    );
  }

  void _updateStatus(MidiConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _statusController.close();
    _messageController.close();
    _configController.close();
  }
}
