import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../types/midi_control_type.dart';
import '../types/connection_state.dart';
import '../constants/app_constants.dart';

/// Service quản lý kết nối WebSocket đến PC server
/// Hỗ trợ auto-reconnect, gửi/nhận MIDI messages
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

  // Throttle: chặn gửi quá nhanh
  DateTime _lastSendTime = DateTime.now();

  /// Stream lắng nghe thay đổi trạng thái kết nối
  Stream<MidiConnectionStatus> get statusStream => _statusController.stream;

  /// Stream lắng nghe messages từ server (feedback)
  Stream<MidiMessage> get messageStream => _messageController.stream;

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

      // Chờ kết nối thành công
      await _channel!.ready;

      _updateStatus(MidiConnectionStatus.connected);
      _reconnectAttempts = 0;

      // Lắng nghe messages từ server
      _channel!.stream.listen(
        (data) {
          try {
            final message = MidiMessage.fromJson(data as String);
            _messageController.add(message);
          } catch (e) {
            debugPrint('⚠️ Parse message error: $e');
          }
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

  /// Ngắt kết nối
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = AppConstants.maxReconnectAttempts; // Ngăn auto-reconnect
    await _channel?.sink.close();
    _channel = null;
    _updateStatus(MidiConnectionStatus.disconnected);
  }

  /// Gửi MIDI message đến server
  void sendMessage(MidiMessage message) {
    if (_status != MidiConnectionStatus.connected || _channel == null) return;

    // Throttle: chặn gửi quá nhanh
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

  /// Gửi nhanh Control Change message
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

  /// Xử lý khi mất kết nối
  void _handleDisconnect() {
    _channel = null;
    _updateStatus(MidiConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  /// Lên lịch tự động kết nối lại
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

  /// Cập nhật và broadcast trạng thái
  void _updateStatus(MidiConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Giải phóng tài nguyên
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _statusController.close();
    _messageController.close();
  }
}
