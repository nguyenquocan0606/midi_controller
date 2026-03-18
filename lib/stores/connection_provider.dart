import 'dart:async';
import 'package:flutter/material.dart';
import '../services/midi_connection_service.dart';
import '../types/midi_control_type.dart';
import '../types/connection_state.dart';

/// Provider quản lý trạng thái kết nối MIDI
/// Cầu nối giữa UI và MidiConnectionService
class ConnectionProvider extends ChangeNotifier {
  final MidiConnectionService _service = MidiConnectionService();
  MidiConnectionStatus _status = MidiConnectionStatus.disconnected;
  ConnectionConfig _config = const ConnectionConfig();
  String _errorMessage = '';
  StreamSubscription<MidiConnectionStatus>? _statusSub;

  ConnectionProvider() {
    _statusSub = _service.statusStream.listen((status) {
      _status = status;
      if (status == MidiConnectionStatus.error) {
        _errorMessage = 'Không thể kết nối đến server';
      }
      notifyListeners();
    });
  }

  // ─── Getters ────────────────────────────────────────
  MidiConnectionStatus get status => _status;
  ConnectionConfig get config => _config;
  String get errorMessage => _errorMessage;
  bool get isConnected => _status == MidiConnectionStatus.connected;
  MidiConnectionService get service => _service;

  // ─── Actions ────────────────────────────────────────

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

  /// Kết nối đến server
  Future<void> connect() async {
    _errorMessage = '';
    await _service.connect(_config);
  }

  /// Ngắt kết nối
  Future<void> disconnect() async {
    await _service.disconnect();
  }

  /// Gửi MIDI Control Change
  void sendCC(int channel, int cc, int value) {
    _service.sendCC(channel, cc, value);
  }

  /// Gửi MIDI message từ MidiControl object
  void sendControl(MidiControl control) {
    _service.sendMessage(control.toMessage());
  }

  /// Gửi Note On
  void sendNoteOn(int channel, int note, int velocity) {
    _service.sendNoteOn(channel, note, velocity);
  }

  /// Gửi Note Off
  void sendNoteOff(int channel, int note) {
    _service.sendNoteOff(channel, note);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
