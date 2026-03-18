import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../stores/connection_provider.dart';
import '../types/connection_state.dart';

/// Trang cài đặt kết nối đến PC server
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

            // ─── Server Configuration ───────────────────
            _buildSectionTitle('SERVER'),
            const SizedBox(height: AppTheme.spacingSm),
            _buildInputCard(connection),
            const SizedBox(height: AppTheme.spacingLg),

            // ─── Connect/Disconnect Button ──────────────
            _buildConnectionButton(connection),
            const SizedBox(height: AppTheme.spacingXl),

            // ─── Setup Guide ────────────────────────────
            _buildSectionTitle('SETUP GUIDE'),
            const SizedBox(height: AppTheme.spacingSm),
            _buildGuideCard(),
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
        statusText = 'Connected to ${connection.config.host}:${connection.config.port}';
        statusIcon = Icons.wifi;
        break;
      case MidiConnectionStatus.connecting:
        statusColor = AppTheme.warning;
        statusText = 'Connecting...';
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card nhập IP và Port
  Widget _buildInputCard(ConnectionProvider connection) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          // Host input
          TextField(
            controller: _hostController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Server IP Address',
              hintText: '192.168.1.100',
              prefixIcon: Icon(Icons.computer, color: AppTheme.textDim),
            ),
            onChanged: (value) {
              connection.updateHost(value);
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Port input
          TextField(
            controller: _portController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '8765',
              prefixIcon:
                  Icon(Icons.numbers, color: AppTheme.textDim),
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
        icon: Icon(
          isConnected ? Icons.link_off : Icons.link,
          color: isConnected ? AppTheme.error : AppTheme.background,
        ),
        label: Text(
          isConnecting
              ? 'CONNECTING...'
              : isConnected
                  ? 'DISCONNECT'
                  : 'CONNECT',
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
  Widget _buildGuideCard() {
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
            'How to setup the PC server:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          _buildGuideStep('1', 'Install loopMIDI and create a virtual MIDI port'),
          _buildGuideStep('2', 'Install Node.js on your PC'),
          _buildGuideStep('3', 'Run the MIDI server script'),
          _buildGuideStep('4', 'Make sure iPad and PC are on the same network'),
          _buildGuideStep('5', 'Enter the PC\'s IP address above and Connect'),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'For USB connection: Enable Personal Hotspot on iPad, '
                    'connect via USB cable, then use the hotspot IP.',
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
