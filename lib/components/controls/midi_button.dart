import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

/// Chế độ hoạt động của button
enum MidiButtonType { momentary, toggle }

/// MIDI Button với LED indicator
/// Momentary: nhấn = ON, thả = OFF
/// Toggle: nhấn = đổi trạng thái
class MidiButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final MidiButtonType type;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final double width;
  final double height;

  const MidiButton({
    super.key,
    required this.label,
    required this.isActive,
    this.type = MidiButtonType.toggle,
    required this.onChanged,
    this.activeColor,
    this.width = 60,
    this.height = 40,
  });

  @override
  State<MidiButton> createState() => _MidiButtonState();
}

class _MidiButtonState extends State<MidiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeOut),
    );

    if (widget.isActive) {
      _glowController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant MidiButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _glowController.forward();
      } else {
        _glowController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown() {
    if (widget.type == MidiButtonType.momentary) {
      widget.onChanged(true);
    }
  }

  void _handleTapUp() {
    if (widget.type == MidiButtonType.momentary) {
      widget.onChanged(false);
    } else {
      // Toggle
      widget.onChanged(!widget.isActive);
    }
  }

  void _handleTapCancel() {
    if (widget.type == MidiButtonType.momentary) {
      widget.onChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? AppTheme.buttonActive;

    return GestureDetector(
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(AppTheme.buttonOff, color, _glowAnimation.value * 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: Color.lerp(
                  AppTheme.surfaceBorder,
                  color,
                  _glowAnimation.value,
                )!,
                width: 1.5,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3 * _glowAnimation.value),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LED indicator dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      AppTheme.textDim.withValues(alpha: 0.3),
                      color,
                      _glowAnimation.value,
                    ),
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                // Label
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Color.lerp(
                          AppTheme.textDim,
                          color,
                          _glowAnimation.value * 0.8,
                        ),
                        fontSize: 9,
                      ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

