import 'dart:async';
import 'package:flutter/material.dart';
import '../services/midi_connection_service.dart';
import '../types/midi_control_type.dart';
import '../types/connection_state.dart';

/// Provider quản lý trạng thái kết nối MIDI
/// Hỗ trợ 2 loại kết nối: WiFi, USB Tethering
class ConnectionProvider extends ChangeNotifier {
  // ─── Services ────────────────────────────────────────
  final MidiConnectionService _wsService = MidiConnectionService();

  // ─── State ───────────────────────────────────────────
  MidiConnectionStatus _status = MidiConnectionStatus.disconnected;
  ConnectionConfig _config = const ConnectionConfig();
  String _errorMessage = '';

  // Subscriptions
  StreamSubscription<MidiConnectionStatus>? _wsStatusSub;

  ConnectionProvider() {
    // Listen to WebSocket service status
    _wsStatusSub = _wsService.statusStream.listen((status) {
      _status = status;
      if (status == MidiConnectionStatus.error) {
        _errorMessage = 'Không thể kết nối đến server';
      }
      notifyListeners();
    });
  }

  // ─── Getters ─────────────────────────────────────────
  MidiConnectionStatus get status => _status;
  ConnectionConfig get config => _config;
  String get errorMessage => _errorMessage;
  bool get isConnected => _status == MidiConnectionStatus.connected;
  MidiConnectionService get wsService => _wsService;

  /// Tên loại kết nối hiện tại
  String get connectionTypeName {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
        return 'WiFi';
      case ConnectionType.usbTethering:
        return 'USB Tethering';
    }
  }

  /// Icon theo loại kết nối
  IconData get connectionIcon {
    switch (_config.connectionType) {
      case ConnectionType.wifi:
        return Icons.wifi;
      case ConnectionType.usbTethering:
        return Icons.usb;
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

  /// Kết nối đến server (WiFi hoặc USB Tethering đều dùng WebSocket)
  Future<void> connect() async {
    _errorMessage = '';
    await _wsService.connect(_config);
  }

  /// Ngắt kết nối
  Future<void> disconnect() async {
    await _wsService.disconnect();
  }

  // ─── Send MIDI ───────────────────────────────────────

  /// Gửi MIDI Control Change
  void sendCC(int channel, int cc, int value) {
    _wsService.sendCC(channel, cc, value);
  }

  /// Gửi MIDI message từ MidiControl object
  void sendControl(MidiControl control) {
    _wsService.sendMessage(control.toMessage());
  }

  /// Gửi Note On
  void sendNoteOn(int channel, int note, int velocity) {
    _wsService.sendNoteOn(channel, note, velocity);
  }

  /// Gửi Note Off
  void sendNoteOff(int channel, int note) {
    _wsService.sendNoteOff(channel, note);
  }

  // ─── Lifecycle ───────────────────────────────────────

  @override
  void dispose() {
    _wsStatusSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
