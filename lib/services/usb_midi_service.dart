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
///
/// Vấn đề đã giải quyết:
/// - USB MIDI devices: liệt kê ngay từ đầu (CoreMIDI tự detect)
/// - BLE MIDI devices: cần scan để tìm thêm
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
  final _scanController = StreamController<bool>.broadcast();

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
  Stream<bool> get isScanningStream => _scanController.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  List<MidiDevice> get devices => _devices;
  MidiDevice? get connectedDevice => _connectedDevice;

  MidiConnectionStatus get status => _isConnected
      ? MidiConnectionStatus.connected
      : MidiConnectionStatus.disconnected;

  // ─── Init ─────────────────────────────────────────────

  UsbMidiService() {
    debugPrint('[USB] UsbMidiService initializing...');

    // Lắng nghe thay đổi MIDI setup (thiết bị cắm/rút)
    _setupChangedSub = _midi.onMidiSetupChanged?.listen((_) {
      debugPrint('[USB] MIDI setup changed - refreshing devices');
      _refreshDevices();
    });

    // Refresh devices ngay khi khởi tạo (USB devices đã được CoreMIDI detect)
    _initDevices();
  }

  /// Load devices ngay khi khởi tạo (CoreMIDI USB devices)
  Future<void> _initDevices() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Chờ CoreMIDI init
    await _refreshDevices();
  }

  // ─── Device Scanning ─────────────────────────────────

  /// Refresh danh sách thiết bị từ CoreMIDI + BLE
  Future<void> _refreshDevices() async {
    try {
      final devs = await _midi.devices;
      if (devs != null) {
        _devices = devs;
        _devicesController.add(devs);
        debugPrint('[USB] CoreMIDI devices found: ${devs.length}');
        for (final d in devs) {
          debugPrint('  - ${d.name} [${d.id}] type=${d.type}');
        }
      } else {
        debugPrint('[USB] No devices returned');
      }
    } catch (e, st) {
      debugPrint('[USB] Refresh devices failed: $e\n$st');
    }
  }

  /// Bắt đầu scan — refresh CoreMIDI devices + scan BLE
  Future<void> startScanning() async {
    if (_isScanning) return;

    _isScanning = true;
    _scanController.add(true);
    _updateStatus(MidiConnectionStatus.connecting);
    debugPrint('[USB] Scanning for MIDI devices...');

    try {
      // 1. Refresh USB devices từ CoreMIDI (luôn cần gọi)
      await _refreshDevices();

      // 2. Start BLE scanning
      await _midi.startScanningForBluetoothDevices();

      // Refresh lại sau khi BLE scan xong
      await Future.delayed(const Duration(seconds: 2));
      await _refreshDevices();

      _isScanning = false;
      _scanController.add(false);
      _updateStatus(MidiConnectionStatus.disconnected);
      debugPrint('[USB] Scan complete. Total devices: ${_devices.length}');
    } catch (e, st) {
      debugPrint('[USB] Scan failed: $e\n$st');
      _isScanning = false;
      _scanController.add(false);
      _updateStatus(MidiConnectionStatus.error);
    }
  }

  /// Dừng scan BLE
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    _midi.stopScanningForBluetoothDevices();
    _isScanning = false;
    _scanController.add(false);
    debugPrint('[USB] Scanning stopped');
  }

  // ─── Connect / Disconnect ─────────────────────────────

  /// Kết nối đến thiết bị MIDI
  Future<bool> connectToDevice(MidiDevice device) async {
    debugPrint('[USB] Connecting to ${device.name}...');

    try {
      await _midi.connectToDevice(device);

      // Listen to MIDI messages
      _midiDataSub?.cancel();
      _midiDataSub = _midi.onMidiDataReceived?.listen((MidiPacket packet) {
        _handleMidiPacket(packet);
      });

      _connectedDevice = device;
      _isConnected = true;
      _updateStatus(MidiConnectionStatus.connected);
      debugPrint('[USB] Connected to ${device.name}');
      return true;
    } catch (e, st) {
      debugPrint('[USB] Connect failed: $e\n$st');
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
  }

  /// Gửi Note On
  void sendNoteOn(int channel, int note, int velocity) {
    if (!_isConnected) return;
    final msg = midi.NoteOnMessage(
        channel: channel, note: note, velocity: velocity);
    _sendWithThrottle(msg);
  }

  /// Gửi Note Off
  void sendNoteOff(int channel, int note) {
    if (!_isConnected) return;
    final msg = midi.NoteOffMessage(channel: channel, note: note, velocity: 0);
    _sendWithThrottle(msg);
  }

  /// Gửi MIDI message
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
          _messageController.add(MidiMessage(
            type: MidiMessageType.controlChange,
            channel: channel,
            control: data[1],
            value: data[2],
          ));
        }
        break;
      case 0x90: // Note On / Note Off (vel=0)
        if (data.length >= 3) {
          _messageController.add(MidiMessage(
            type: data[2] == 0
                ? MidiMessageType.noteOff
                : MidiMessageType.noteOn,
            channel: channel,
            control: data[1],
            value: data[2],
          ));
        }
        break;
      case 0x80: // Note Off
        if (data.length >= 3) {
          _messageController.add(MidiMessage(
            type: MidiMessageType.noteOff,
            channel: channel,
            control: data[1],
            value: 0,
          ));
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
    _scanController.close();
    _midi.dispose();
  }
}
