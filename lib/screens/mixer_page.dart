import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/app_constants.dart';
import '../stores/connection_provider.dart';
import '../types/connection_state.dart';
import '../components/controls/midi_fader.dart';
import '../components/controls/midi_pad.dart';

/// Trang chính: Bàn trộn MIDI (Redesigned)
/// Layout chia 2 phần: Nửa trên (Faders) - Nửa dưới (Pads 5x3)
class MixerPage extends StatefulWidget {
  const MixerPage({super.key});

  @override
  State<MixerPage> createState() => _MixerPageState();
}

class _MixerPageState extends State<MixerPage> {
  // Giá trị faders (8 channel)
  final List<double> _faderValues =
      List.filled(AppConstants.defaultFaderCount, 0.0);

  // Labels cho faders
  final List<String> _faderLabels = [
    'CH 1', 'CH 2', 'CH 3', 'CH 4',
    'CH 5', 'CH 6', 'CH 7', 'MASTER',
  ];

  // Labels cho 15 pads
  final List<String> _padLabels = List.generate(
      AppConstants.defaultPadCount, (index) => 'PAD ${index + 1}');

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ────────────────────────────────
            _buildTopBar(connection),
            
            // ─── Nửa trên: Faders (flex: 4) ─────────────
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.surface,
                      AppTheme.surfaceLight.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 1),
                  ],
                ),
                child: _buildFadersSection(connection),
              ),
            ),

            // ─── Nửa dưới: Pads 5x3 (flex: 5) ────────────
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.surfaceLight.withValues(alpha: 0.5),
                      AppTheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 1),
                  ],
                ),
                child: _buildPadsSection(connection),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top bar: App name + Connection status + Settings button
  Widget _buildTopBar(ConnectionProvider connection) {
    Color statusColor;
    String statusText;

    switch (connection.status) {
      case MidiConnectionStatus.connected:
        statusColor = AppTheme.success;
        statusText = 'CONNECTED';
        break;
      case MidiConnectionStatus.connecting:
        statusColor = AppTheme.warning;
        statusText = 'CONNECTING...';
        break;
      case MidiConnectionStatus.error:
        statusColor = AppTheme.error;
        statusText = 'ERROR';
        break;
      default:
        statusColor = AppTheme.textDim;
        statusText = 'OFFLINE';
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: const Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 2)),
      ),
      child: Row(
        children: [
          // Giao diện đẹp hơn cho title
          Row(
            children: [
              Icon(Icons.tune, color: AppTheme.primary, size: 24),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                'STUDIO CONTROLLER',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
              ),
            ],
          ),
          const Spacer(),
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          // Settings button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              icon: const Icon(Icons.settings, color: AppTheme.textPrimary),
              iconSize: 22,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  /// Section: 8 Faders dọc (Nửa trên)
  Widget _buildFadersSection(ConnectionProvider connection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final faderWidth = (constraints.maxWidth / AppConstants.defaultFaderCount) - 16;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(AppConstants.defaultFaderCount, (index) {
            final isMaster = index == AppConstants.defaultFaderCount - 1;
            return MidiFader(
              label: _faderLabels[index],
              value: _faderValues[index],
              activeColor: isMaster ? AppTheme.accent : AppTheme.primary,
              width: faderWidth.clamp(40.0, 80.0),
              onChanged: (value) {
                setState(() {
                  _faderValues[index] = value;
                });
                // CC 1-8 cho faders
                connection.sendCC(0, 1 + index, (value * 127).round());
              },
            );
          }),
        );
      }
    );
  }

  /// Section: 15 Pads (Nửa dưới) - Grid 5 columns x 3 rows
  Widget _buildPadsSection(ConnectionProvider connection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tự tính toán tỷ lệ aspect ratio để fit đúng box
        final maxCrossAxisExtent = constraints.maxWidth / 5;
        final maxMainAxisExtent = constraints.maxHeight / 3;
        final aspectRatio = maxCrossAxisExtent / maxMainAxisExtent;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // Vừa màn hình không cần scroll
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: AppTheme.spacingMd,
            mainAxisSpacing: AppTheme.spacingMd,
            childAspectRatio: aspectRatio,
          ),
          itemCount: AppConstants.defaultPadCount,
          itemBuilder: (context, index) {
            return MidiPad(
              label: _padLabels[index],
              activeColor: AppTheme.padActive,
              onNoteOn: (velocity) {
                // Note 36-50 (GM Drum map starting from C2)
                connection.sendNoteOn(9, 36 + index, velocity);
              },
              onNoteOff: () {
                connection.sendNoteOff(9, 36 + index);
              },
            );
          },
        );
      }
    );
  }
}

