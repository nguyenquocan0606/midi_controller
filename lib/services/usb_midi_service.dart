import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart' as midi;
import '../types/midi_control_type.dart';
import '../types/connection_state.dart';

/// Service quản lý kết nối USB / Bluetooth MIDI
///
/// flutter_midi_command dùng CoreMIDI trên iOS — tự động nhận diện
/// tất cả thiết bị MIDI vật lý (USB, Bluetooth) qua CoreMIDI.
/// Không cần cấu hình riêng cho USB.
///
/// Hỗ trợ 2 chế độ:
/// 1. USB Tethering: iPad kết nối WebSocket qua mạng USB network
/// 2. Bluetooth / USB MIDI: iPad gửi MIDI trực tiếp qua thiết bị vật lý
class UsbMidiService {
  // ─── Singleton MidiCommand ────────────────────────────
  final MidiCommand _midi = MidiCommand();

  // ─── State ────────────────────────────────────────────
  bool _isScanning = false;
  bool _isConnected = false;
  MidiDevice? _connectedDevice;

  // Stream controllers
  final _statusController =
      StreamController<MidiConnectionStatus>.broadcast();
  final _messageController = StreamController<MidiMessage>.broadcast();
  final _devicesController = StreamController<List<MidiDevice>>.broadcast();

  // Devices list
  List<MidiDevice> _devices = [];

  // Throttle
  DateTime _lastSendTime = DateTime.now();

  // Subscriptions
  StreamSubscription<MidiPacket?>? _midiDataSub;
  StreamSubscription<String>? _setupChangedSub;

  // ─── Getters ─────────────────────────────────────────

  Stream<MidiConnectionStatus> get statusStream => _statusController.stream;
  Stream<MidiMessage> get messageStream => _messageController.stream;
  Stream<List<MidiDevice>> get devicesStream => _devicesController.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  List<MidiDevice> get devices => _devices;
  MidiDevice? get connectedDevice => _connectedDevice;

  MidiConnectionStatus get status => _isConnected
      ? MidiConnectionStatus.connected
      : MidiConnectionStatus.disconnected;

  // ─── Init ─────────────────────────────────────────────

  UsbMidiService() {
    // Lắng nghe thay đổi MIDI setup (thiết bị cắm/rút)
    _setupChangedSub = _midi.onMidiSetupChanged?.listen((_) {
      _refreshDevices();
    });
  }

  // ─── Device Scanning ─────────────────────────────────

  /// Refresh danh sách thiết bị
  Future<void> _refreshDevices() async {
    try {
      final devs = await _midi.devices;
      if (devs != null) {
        _devices = devs;
        _devicesController.add(_devices);
        debugPrint('[USB] Devices: ${devs.length}');
        for (final d in devs) {
          debugPrint('  - ${d.name} (${d.id})');
        }
      }
    } catch (e) {
      debugPrint('[USB] Refresh devices failed: $e');
    }
  }

  /// Bắt đầu scan thiết bị MIDI (BLE scanning)
  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    _updateStatus(MidiConnectionStatus.connecting);
    debugPrint('[USB] Scanning for MIDI devices...');

    try {
      // Refresh devices list from CoreMIDI (USB devices)
      await _refreshDevices();

      // Also start BLE scanning if needed
      await _midi.startScanningForBluetoothDevices();

      _isScanning = false;
      _updateStatus(MidiConnectionStatus.disconnected);
    } catch (e) {
      debugPrint('[USB] Scan failed: $e');
      _isScanning = false;
      _updateStatus(MidiConnectionStatus.error);
    }
  }

  /// Dừng scan
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    _midi.stopScanningForBluetoothDevices();
    _isScanning = false;
    debugPrint('[USB] Scanning stopped');
  }

  // ─── Connect / Disconnect ─────────────────────────────

  /// Kết nối đến thiết bị MIDI
  Future<bool> connectToDevice(MidiDevice device) async {
    debugPrint('[USB] Connecting to ${device.name}...');

    try {
      await _midi.connectToDevice(device);

      // Listen to MIDI messages from this device
      _midiDataSub?.cancel();
      _midiDataSub = _midi.onMidiDataReceived?.listen((MidiPacket packet) {
        _handleMidiPacket(packet);
      });

      _connectedDevice = device;
      _isConnected = true;
      _updateStatus(MidiConnectionStatus.connected);
      debugPrint('[USB] Connected to ${device.name}');
      return true;
    } catch (e) {
      debugPrint('[USB] Connect failed: $e');
      _isConnected = false;
      _updateStatus(MidiConnectionStatus.error);
      return false;
    }
  }

  /// Ngắt kết nối
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      _midi.disconnectDevice(_connectedDevice!);
      _connectedDevice = null;
    }
    _midiDataSub?.cancel();
    _midiDataSub = null;
    _isConnected = false;
    _updateStatus(MidiConnectionStatus.disconnected);
    debugPrint('[USB] Disconnected');
  }

  // ─── Send MIDI ────────────────────────────────────────

  /// Gửi Control Change
  void sendCC(int channel, int cc, int value) {
    if (!_isConnected) return;
    final msg = midi.CCMessage(channel: channel, controller: cc, value: value);
    _sendWithThrottle(msg);
    debugPrint('[USB] CC Ch:$channel CC:$cc Val:$value');
  }

  /// Gửi Note On
  void sendNoteOn(int channel, int note, int velocity) {
    if (!_isConnected) return;
    final msg = midi.NoteOnMessage(
        channel: channel, note: note, velocity: velocity);
    _sendWithThrottle(msg);
    debugPrint('[USB] NoteOn Ch:$channel Note:$note Vel:$velocity');
  }

  /// Gửi Note Off
  void sendNoteOff(int channel, int note) {
    if (!_isConnected) return;
    final msg = midi.NoteOffMessage(channel: channel, note: note, velocity: 0);
    _sendWithThrottle(msg);
    debugPrint('[USB] NoteOff Ch:$channel Note:$note');
  }

  /// Gửi MIDI message từ MidiMessage object
  void sendMessage(MidiMessage message) {
    switch (message.type) {
      case MidiMessageType.controlChange:
        sendCC(message.channel, message.control, message.value);
        break;
      case MidiMessageType.noteOn:
        sendNoteOn(message.channel, message.control, message.value);
        break;
      case MidiMessageType.noteOff:
        sendNoteOff(message.channel, message.control);
        break;
    }
  }

  /// Gửi message có throttle
  void _sendWithThrottle(midi.MidiMessage msg) {
    final now = DateTime.now();
    if (now.difference(_lastSendTime).inMilliseconds < 10) return;
    _lastSendTime = now;
    msg.send();
  }

  // ─── Parse Incoming MIDI ──────────────────────────────

  void _handleMidiPacket(MidiPacket packet) {
    final data = packet.data;
    if (data.isEmpty) return;

    final status = data[0];
    final type = status & 0xF0;
    final channel = status & 0x0F;

    switch (type) {
      case 0xB0: // Control Change
        if (data.length >= 3) {
          final cc = data[1];
          final value = data[2];
          final msg = MidiMessage(
            type: MidiMessageType.controlChange,
            channel: channel,
            control: cc,
            value: value,
          );
          _messageController.add(msg);
          debugPrint('[USB RX] CC Ch:$channel CC:$cc Val:$value');
        }
        break;

      case 0x90: // Note On
        if (data.length >= 3) {
          final note = data[1];
          final velocity = data[2];
          final msg = MidiMessage(
            type: velocity == 0
                ? MidiMessageType.noteOff
                : MidiMessageType.noteOn,
            channel: channel,
            control: note,
            value: velocity,
          );
          _messageController.add(msg);
          debugPrint('[USB RX] Note Ch:$channel Note:$note Vel:$velocity');
        }
        break;

      case 0x80: // Note Off
        if (data.length >= 3) {
          final note = data[1];
          final msg = MidiMessage(
            type: MidiMessageType.noteOff,
            channel: channel,
            control: note,
            value: 0,
          );
          _messageController.add(msg);
          debugPrint('[USB RX] NoteOff Ch:$channel Note:$note');
        }
        break;
    }
  }

  // ─── Helpers ─────────────────────────────────────────

  void _updateStatus(MidiConnectionStatus newStatus) {
    _statusController.add(newStatus);
  }

  /// Giải phóng tài nguyên
  void dispose() {
    _midiDataSub?.cancel();
    _setupChangedSub?.cancel();
    _statusController.close();
    _messageController.close();
    _devicesController.close();
    _midi.dispose();
  }
}
