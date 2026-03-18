import 'dart:convert';

/// Phân loại các loại MIDI control
enum MidiControlType { fader, knob, button, pad }

/// Chế độ hoạt động của Button
enum MidiButtonMode { momentary, toggle }

/// Định nghĩa 1 MIDI control trên giao diện
class MidiControl {
  final String id;
  final MidiControlType type;
  final int channel; // MIDI channel 0-15
  final int cc; // Control Change number 0-127
  final String label;
  double value; // 0.0 - 1.0 (sẽ được map sang 0-127 khi gửi)

  MidiControl({
    required this.id,
    required this.type,
    this.channel = 0,
    required this.cc,
    required this.label,
    this.value = 0.0,
  });

  /// Chuyển đổi value (0.0-1.0) sang MIDI value (0-127)
  int get midiValue => (value * 127).round().clamp(0, 127);

  /// Tạo MidiMessage từ control hiện tại
  MidiMessage toMessage() {
    return MidiMessage(
      type: MidiMessageType.controlChange,
      channel: channel,
      control: cc,
      value: midiValue,
    );
  }
}

/// Loại MIDI message
enum MidiMessageType { controlChange, noteOn, noteOff }

/// Message gửi qua WebSocket đến PC server
class MidiMessage {
  final MidiMessageType type;
  final int channel;
  final int control; // CC number hoặc Note number
  final int value; // 0-127

  const MidiMessage({
    required this.type,
    required this.channel,
    required this.control,
    required this.value,
  });

  /// Serialize thành JSON string để gửi qua WebSocket
  String toJson() {
    return jsonEncode({
      'type': type.name,
      'channel': channel,
      'control': control,
      'value': value,
    });
  }

  /// Parse từ JSON string nhận từ server (feedback)
  factory MidiMessage.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MidiMessage(
      type: MidiMessageType.values.byName(map['type'] as String),
      channel: map['channel'] as int,
      control: map['control'] as int,
      value: map['value'] as int,
    );
  }

  @override
  String toString() =>
      'MidiMessage(type: ${type.name}, ch: $channel, cc: $control, val: $value)';
}
