import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../stores/connection_provider.dart';
import '../types/connection_state.dart';
import '../types/midi_control_type.dart';
import '../types/app_config.dart';
import '../components/controls/midi_fader.dart';
import '../components/controls/midi_pad.dart';

/// Trang chính: Bàn trộn MIDI
/// Tất cả groups hiển thị trên 1 trang, mỗi group có 3 faders
class MixerPage extends StatefulWidget {
  const MixerPage({super.key});

  @override
  State<MixerPage> createState() => _MixerPageState();
}

class _MixerPageState extends State<MixerPage> {
  AppConfig _config = AppConfig.defaults();
  final Map<int, double> _faderValues = {};
  /// active pad trong mỗi Layer (Layer -> padId)
  final Map<int, int?> _activePadPerLayer = {};
  StreamSubscription? _feedbackSub;
  StreamSubscription? _configSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStreams();
    });
  }

  void _initStreams() {
    final connection = context.read<ConnectionProvider>();

    _feedbackSub = connection.wsService.messageStream.listen((msg) {
      if (msg.type == MidiMessageType.controlChange) {
        // msg.control = CC number 1-9 (global channel index + 1)
        setState(() {
          _faderValues[msg.control] = msg.value / 127.0;
        });
      }
    });

    _configSub = connection.wsService.configStream.listen((cfg) {
      setState(() {
        _config = cfg;
      });
    });
  }

  @override
  void dispose() {
    _feedbackSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(connection),
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: _sectionDecoration(),
                child: _buildFadersSection(connection),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: _sectionDecoration(),
                child: _buildPadsSection(connection),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
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
    );
  }

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
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceBorder, width: 2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: AppTheme.primary, size: 24),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            'STUDIO CONTROLLER',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
          ),
          const Spacer(),
          _buildStatusBadge(statusColor, statusText),
          const SizedBox(width: AppTheme.spacingMd),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: IconButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
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

  Widget _buildStatusBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
    );
  }

  /// Faders: tất cả groups trên 1 trang
  /// Mỗi group là 1 column group với 3 faders
  Widget _buildFadersSection(ConnectionProvider connection) {
    final groups = _config.groups;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tính width cho mỗi group (3 faders)
        final groupCount = groups.length;
        final groupWidth = (constraints.maxWidth - (groupCount - 1) * AppTheme.spacingMd) / groupCount;
        final faderWidth = (groupWidth / 3).clamp(40.0, 80.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int gi = 0; gi < groups.length; gi++) ...[
              if (gi > 0) const SizedBox(width: AppTheme.spacingMd),
              _buildGroupColumn(groups[gi], faderWidth, connection, gi),
            ],
          ],
        );
      },
    );
  }

  /// Một group column với 3 faders + group name header
  Widget _buildGroupColumn(GroupConfig group, double faderWidth, ConnectionProvider connection, int groupIndex) {
    return Expanded(
      child: Column(
        children: [
          // Group name header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              group.name,
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 3 faders
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (chIndex) {
                final ch = chIndex < group.channels.length
                    ? group.channels[chIndex]
                    : ChannelConfig(id: chIndex, name: 'CH ${groupIndex * 3 + chIndex + 1}');
                // Global channel index cho CC
                final globalCh = groupIndex * 3 + chIndex;
                final value = _faderValues[globalCh + 1] ?? 0.0;

                return MidiFader(
                  label: ch.name,
                  value: value,
                  activeColor: ch.color != null
                      ? _parseColor(ch.color!)
                      : AppTheme.primary,
                  width: faderWidth,
                  onChanged: (newValue) {
                    setState(() => _faderValues[globalCh + 1] = newValue);
                    connection.sendCC(0, globalCh + 1, (newValue * 127).round());
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadsSection(ConnectionProvider connection) {
    final layout = _config.padLayout;
    final pads = _config.pads;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCrossExtent = constraints.maxWidth / layout.columns;
        final maxMainExtent = constraints.maxHeight / layout.rows;
        final aspectRatio = maxCrossExtent / maxMainExtent;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.columns,
            crossAxisSpacing: AppTheme.spacingMd,
            mainAxisSpacing: AppTheme.spacingMd,
            childAspectRatio: aspectRatio,
          ),
          itemCount: layout.totalPads,
          itemBuilder: (context, index) {
            if (index >= pads.length) {
              return MidiPad(
                label: 'PAD ${index + 1}',
                customColor: AppTheme.padActive,
                onNoteOn: (v) {},
                onNoteOff: () {},
              );
            }

            final pad = pads[index];
            final isActive = _activePadPerLayer[pad.layerId] == pad.id;
            return MidiPad(
              label: pad.name,
              customColor: pad.color != null ? _parseColor(pad.color!) : null,
              imageUrl: pad.imageUrl,
              isLayerActive: isActive,
              onNoteOn: (velocity) {
                // Layer mutual exclusion: khi pad mới được ấn, clear pad cũ trong cùng layer
                setState(() => _activePadPerLayer[pad.layerId] = pad.id);
                connection.sendNoteOn(9, 36 + index, velocity);
              },
              onNoteOff: () {
                // Note-off gửi MIDI nhưng KHÔNG xóa active state của Layer
                // Pad giữ sáng cho đến khi pad khác cùng Layer được bấm
                connection.sendNoteOff(9, 36 + index);
              },
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      if (hex.startsWith('#')) {
        return Color(int.parse('FF${hex.substring(1)}', radix: 16));
      }
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppTheme.primary;
    }
  }
}

