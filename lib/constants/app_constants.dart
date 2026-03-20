/// Hằng số MIDI
class MidiConstants {
  MidiConstants._();

  /// Giá trị MIDI tối thiểu
  static const int minValue = 0;

  /// Giá trị MIDI tối đa
  static const int maxValue = 127;

  /// Số channels MIDI (0-15)
  static const int maxChannels = 16;

  /// Số CC tối đa
  static const int maxCC = 127;
}

/// Hằng số ứng dụng
class AppConstants {
  AppConstants._();

  /// Tên app
  static const String appName = 'MIDI Controller';

  /// Default server port
  static const int defaultPort = 8765;

  /// Default server host
  static const String defaultHost = '192.168.1.100';

  /// Thời gian chờ reconnect (ms)
  static const int reconnectIntervalMs = 3000;

  /// Số lần retry tối đa
  static const int maxReconnectAttempts = 10;

  /// Throttle gửi message (ms) - tránh flood server
  static const int messageThrottleMs = 10;

  /// Số faders mặc định trên mixer
  static const int defaultFaderCount = 10;

  /// Số knobs mặc định
  static const int defaultKnobCount = 8;

  /// Số buttons mặc định
  static const int defaultButtonCount = 16;

  /// Số pads mặc định
  static const int defaultPadCount = 15;
}
