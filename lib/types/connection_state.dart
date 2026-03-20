/// Trạng thái kết nối WebSocket đến PC server
enum MidiConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Loại kết nối
enum ConnectionType {
  /// WiFi: WebSocket qua mạng LAN/WiFi
  wifi,

  /// USB Tethering: WebSocket qua USB network interface (iPad cắm USB-C vào PC)
  usbTethering,
}

/// Cấu hình kết nối đến PC server
class ConnectionConfig {
  final String host;
  final int port;
  final ConnectionType connectionType;

  const ConnectionConfig({
    this.host = '192.168.1.100',
    this.port = 8765,
    this.connectionType = ConnectionType.wifi,
  });

  /// WebSocket URL
  String get wsUrl => 'ws://$host:$port';

  ConnectionConfig copyWith({String? host, int? port, ConnectionType? connectionType}) {
    return ConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      connectionType: connectionType ?? this.connectionType,
    );
  }

  @override
  String toString() => 'ConnectionConfig($connectionType, $host:$port)';
}
