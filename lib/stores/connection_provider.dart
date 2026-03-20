import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import '../services/midi_connection_service.dart';
import '../services/usb_midi_service.dart';
import '../types/midi_control_type.dart';
import '../types/connection_state.dart';

/// Provider quản lý trạng thái kết nối MIDI
/// Hỗ trợ 3 loại kết nối: WiFi, USB Tethering, USB MIDI
class ConnectionProvider extends ChangeNotifier {
  // ─── Services ────────────────────────────────────────
  final MidiConnectionService _wsService = MidiConnectionService();
  final UsbMidiService _usbService = UsbMidiService();

  // ─── State ───────────────────────────────────────────
  MidiConnectionStatus _status = MidiConnectionStatus.disconnected;
  ConnectionConfig _config = const ConnectionConfig();
  String _errorMessage = '';
  String _usbDeviceName = '';

  // Subscriptions
  StreamSubscription<MidiConnectionStatus>? _wsStatusSub;
  StreamSubscription<MidiConnectionStatus>? _usbStatusSub;
  StreamSubscription<MidiMessage>? _usbMessageSub;

  ConnectionProvider() {
    // Listen to WebSocket service status
    _wsStatusSub = _wsService.statusStream.listen((status) {
      _status = status;
      if (status == MidiConnectionStatus.error) {
        _errorMessage = 'Không thể kết nối đến server';
      }
      notifyListeners();
    });

    // Listen to USB MIDI service status
    _usbStatusSub = _usbService.statusStream.listen((status) {
      // USB service uses its own status, but we sync to main status
      _status = status;
      notifyListeners();
    });

    // Forward USB MIDI messages to app (for USB MIDI mode)
    _usbMessageSub = _usbService.messageStream.listen((message) {
      // Messages are forwarded through the app's MIDI handling
    });
  }

  // ─── Getters ─────────────────────────────────────────
  MidiConnectionStatus get status => _status;
  ConnectionConfig get config => _config;
  String get errorMessage => _errorMessage;
  String get usbDeviceName => _usbDeviceName;
  bool get isConnected => _status == MidiConnectionStatus.connected;
  MidiConnectionService get wsService => _wsService;
  UsbMidiService get usbService => _usbService;

  /// Tên loại kết nối hiện tại
  String get connectionTypeName {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
        return 'WiFi';
      case ConnectionType.usbTethering:
        return 'USB Tethering';
      case ConnectionType.usbMidi:
        return 'USB MIDI';
    }
  }

  /// Icon theo loại kết nối
  IconData get connectionIcon {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
        return Icons.wifi;
      case ConnectionType.usbTethering:
        return Icons.usb;
      case ConnectionType.usbMidi:
        return Icons.music_note;
    }
  }

  // ─── Connection Type ─────────────────────────────────

  /// Chọn loại kết nối
  void setConnectionType(ConnectionType type) {
    _config = _config.copyWith(connectionType: type);
    notifyListeners();
  }

  // ─── Config Updates ──────────────────────────────────

  /// Cập nhật host
  void updateHost(String host) {
    _config = _config.copyWith(host: host);
    notifyListeners();
  }

  /// Cập nhật port
  void updatePort(int port) {
    _config = _config.copyWith(port: port);
    notifyListeners();
  }

  // ─── Connect / Disconnect ─────────────────────────────

  /// Kết nối đến server
  Future<void> connect() async {
    _errorMessage = '';

    switch (_config.connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.usbTethering:
        // Both use WebSocket - same connect logic
        await _wsService.connect(_config);
        break;

      case ConnectionType.usbMidi:
        // USB MIDI: scan and connect to first device
        await _usbService.startScanning();
        break;
    }
  }

  /// Ngắt kết nối
  Future<void> disconnect() async {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.usbTethering:
        await _wsService.disconnect();
        break;
      case ConnectionType.usbMidi:
        await _usbService.disconnect();
        break;
    }
  }

  // ─── Send MIDI ───────────────────────────────────────

  /// Gửi MIDI Control Change
  void sendCC(int channel, int cc, int value) {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.usbTethering:
        _wsService.sendCC(channel, cc, value);
        break;
      case ConnectionType.usbMidi:
        _usbService.sendMessage(MidiMessage(
          type: MidiMessageType.controlChange,
          channel: channel,
          control: cc,
          value: value,
        ));
        break;
    }
  }

  /// Gửi MIDI message từ MidiControl object
  void sendControl(MidiControl control) {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.usbTethering:
        _wsService.sendMessage(control.toMessage());
        break;
      case ConnectionType.usbMidi:
        _usbService.sendMessage(control.toMessage());
        break;
    }
  }

  /// Gửi Note On
  void sendNoteOn(int channel, int note, int velocity) {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.usbTethering:
        _wsService.sendNoteOn(channel, note, velocity);
        break;
      case ConnectionType.usbMidi:
        _usbService.sendMessage(MidiMessage(
          type: MidiMessageType.noteOn,
          channel: channel,
          control: note,
          value: velocity,
        ));
        break;
    }
  }

  /// Gửi Note Off
  void sendNoteOff(int channel, int note) {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
      case ConnectionType.usbTethering:
        _wsService.sendNoteOff(channel, note);
        break;
      case ConnectionType.usbMidi:
        _usbService.sendMessage(MidiMessage(
          type: MidiMessageType.noteOff,
          channel: channel,
          control: note,
          value: 0,
        ));
        break;
    }
  }

  // ─── USB Specific ────────────────────────────────────

  /// Scan thiết bị USB MIDI
  Future<void> scanUsbDevices() async {
    await _usbService.startScanning();
  }

  /// Kết nối đến thiết bị USB MIDI cụ thể
  Future<bool> connectUsbDevice(MidiDevice device) async {
    final success = await _usbService.connectToDevice(device);
    if (success) {
      _usbDeviceName = device.name;
    }
    return success;
  }

  // ─── Lifecycle ───────────────────────────────────────

  @override
  void dispose() {
    _wsStatusSub?.cancel();
    _usbStatusSub?.cancel();
    _usbMessageSub?.cancel();
    _wsService.dispose();
    _usbService.dispose();
    super.dispose();
  }
}
