/// Trạng thái kết nối WebSocket đến PC server
enum MidiConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Cấu hình kết nối đến PC server
class ConnectionConfig {
  final String host;
  final int port;

  const ConnectionConfig({
    this.host = '192.168.1.100',
    this.port = 8765,
  });

  /// WebSocket URL
  String get wsUrl => 'ws://$host:$port';

  ConnectionConfig copyWith({String? host, int? port}) {
    return ConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  @override
  String toString() => 'ConnectionConfig($host:$port)';
}
