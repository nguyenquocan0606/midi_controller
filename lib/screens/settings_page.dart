import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../stores/connection_provider.dart';
import '../types/connection_state.dart';

/// Trang cài đặt kết nối đến PC server
/// Hỗ trợ WiFi, USB Tethering
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConnectionProvider>().config;
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CONNECTION SETTINGS',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Connection Status Card ─────────────────
            _buildStatusCard(connection),
            const SizedBox(height: AppTheme.spacingLg),

            // ─── Connection Type Selector ─────────────
            _buildSectionTitle('CONNECTION TYPE'),
            const SizedBox(height: AppTheme.spacingSm),
            _buildConnectionTypeSelector(connection),
            const SizedBox(height: AppTheme.spacingLg),

            // ─── Server Configuration ─────────────────
            if (connection.config.connectionType == ConnectionType.wifi ||
                connection.config.connectionType == ConnectionType.usbTethering) ...[
              _buildSectionTitle('SERVER ADDRESS'),
              const SizedBox(height: AppTheme.spacingSm),
              _buildInputCard(connection),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // ─── Connect/Disconnect Button ──────────────
            _buildConnectionButton(connection),
            const SizedBox(height: AppTheme.spacingXl),

            // ─── Setup Guide ────────────────────────────
            _buildSectionTitle('SETUP GUIDE'),
            const SizedBox(height: AppTheme.spacingSm),
            _buildGuideCard(connection),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textDim,
            letterSpacing: 3,
          ),
    );
  }

  /// Card hiển thị trạng thái kết nối
  Widget _buildStatusCard(ConnectionProvider connection) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (connection.status) {
      case MidiConnectionStatus.connected:
        statusColor = AppTheme.success;
        statusText =
            '${connection.connectionTypeName} • ${connection.config.host}:${connection.config.port}';
        statusIcon = connection.connectionIcon;
        break;
      case MidiConnectionStatus.connecting:
        statusColor = AppTheme.warning;
        statusText = 'Connecting via ${connection.connectionTypeName}...';
        statusIcon = Icons.sync;
        break;
      case MidiConnectionStatus.error:
        statusColor = AppTheme.error;
        statusText = connection.errorMessage;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = AppTheme.textDim;
        statusText = 'Not connected';
        statusIcon = Icons.wifi_off;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Selector chọn loại kết nối
  Widget _buildConnectionTypeSelector(ConnectionProvider connection) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          _buildConnectionTypeOption(
            connection,
            ConnectionType.wifi,
            Icons.wifi,
            'WiFi',
            'iPad và PC cùng mạng WiFi',
          ),
          _divider(),
          _buildConnectionTypeOption(
            connection,
            ConnectionType.usbTethering,
            Icons.usb,
            'USB Tethering',
            'Cắm USB-C • Nhanh & ổn định • Vừa sạc iPad',
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 60,
      color: AppTheme.surfaceBorder,
    );
  }

  Widget _buildConnectionTypeOption(
    ConnectionProvider connection,
    ConnectionType type,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = connection.config.connectionType == type;

    return InkWell(
      onTap: () => connection.setConnectionType(type),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primary : AppTheme.textDim,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textDim,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }

  /// Card nhập IP và Port
  Widget _buildInputCard(ConnectionProvider connection) {
    final isUsbTethering =
        connection.config.connectionType == ConnectionType.usbTethering;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          // USB Tethering hint
          if (isUsbTethering) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.usb, color: AppTheme.primary, size: 18),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      '1. Cắm iPad vào PC qua USB-C\n'
                      '2. iPad: Settings → Personal Hotspot → USB Tethering ON\n'
                      '3. Chạy server trên PC → xem USB IP ở console\n'
                      '4. Nhập USB IP bên dưới',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primary,
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],

          // Host input
          TextField(
            controller: _hostController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Server IP Address',
              hintText: isUsbTethering ? '172.20.10.x (USB IP)' : '192.168.1.100',
              prefixIcon:
                  const Icon(Icons.computer, color: AppTheme.textDim),
              helperText: isUsbTethering
                  ? 'USB IP: xem console server khi chạy node server.js'
                  : null,
              helperStyle: const TextStyle(color: AppTheme.primary),
            ),
            onChanged: (value) => connection.updateHost(value),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Port input
          TextField(
            controller: _portController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '8765',
              prefixIcon: Icon(Icons.numbers, color: AppTheme.textDim),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final port = int.tryParse(value);
              if (port != null && port > 0 && port < 65536) {
                connection.updatePort(port);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Nút Connect / Disconnect
  Widget _buildConnectionButton(ConnectionProvider connection) {
    final isConnected = connection.isConnected;
    final isConnecting =
        connection.status == MidiConnectionStatus.connecting;

    String buttonLabel;
    if (isConnecting) {
      buttonLabel = 'CONNECTING...';
    } else if (isConnected) {
      buttonLabel = 'DISCONNECT';
    } else {
      buttonLabel = connection.config.connectionType == ConnectionType.usbTethering
          ? 'CONNECT VIA USB'
          : 'CONNECT VIA WIFI';
    }

    IconData buttonIcon;
    if (isConnected) {
      buttonIcon = Icons.link_off;
    } else if (connection.config.connectionType == ConnectionType.usbTethering) {
      buttonIcon = Icons.usb;
    } else {
      buttonIcon = Icons.wifi;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isConnecting
            ? null
            : () async {
                if (isConnected) {
                  await connection.disconnect();
                } else {
                  await connection.connect();
                }
              },
        icon: Icon(buttonIcon,
            color: isConnected ? AppTheme.error : AppTheme.background),
        label: Text(
          buttonLabel,
          style: TextStyle(
            letterSpacing: 2,
            color: isConnected ? AppTheme.error : AppTheme.background,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isConnected ? AppTheme.surface : AppTheme.primary,
          side: isConnected
              ? const BorderSide(color: AppTheme.error)
              : null,
        ),
      ),
    );
  }

  /// Card hướng dẫn setup server
  Widget _buildGuideCard(ConnectionProvider connection) {
    final isUsb = connection.config.connectionType == ConnectionType.usbTethering;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PC Server Setup:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),

          if (!isUsb) ...[
            _buildGuideStep('1', 'Chạy server: cd script/midi-server && node server.js'),
            _buildGuideStep('2', 'Copy IP của PC từ console server'),
            _buildGuideStep('3', 'Nhập IP vào app → CONNECT'),
          ],

          if (isUsb) ...[
            _buildGuideStep('1', 'Chạy server: node server.js'),
            _buildGuideStep('2', 'Server tự detect USB IP → copy IP đó'),
            _buildGuideStep('3', 'Nhập USB IP vào app → CONNECT'),
            _buildGuideStep('4', '✓ USB Tethering: nhanh, sạc iPad, không cần WiFi!'),
          ],

          const SizedBox(height: AppTheme.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    isUsb
                        ? 'USB Tethering khuyến nghị: độ trễ thấp, ổn định!'
                        : 'PC và iPad phải cùng mạng WiFi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                    ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
