import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

/// MIDI Pad - Velocity-sensitive drum pad
/// Ấn nhanh = velocity cao, ấn chậm = velocity thấp
class MidiPad extends StatefulWidget {
  final String label;
  final ValueChanged<int> onNoteOn; // velocity 0-127
  final VoidCallback onNoteOff;
  final Color? activeColor;
  final double? size;

  const MidiPad({
    super.key,
    required this.label,
    required this.onNoteOn,
    required this.onNoteOff,
    this.activeColor,
    this.size,
  });

  @override
  State<MidiPad> createState() => _MidiPadState();
}

class _MidiPadState extends State<MidiPad>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  double _velocity = 0.0;
  DateTime? _touchStartTime;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _touchStartTime = DateTime.now();
    setState(() {
      _isPressed = true;
      _velocity = 1.0; // Mặc định velocity max
    });
    _fadeController.reset();
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Tính velocity dựa trên thời gian nhấn:
    // Nhấn cực nhanh (<50ms) = velocity 127
    // Nhấn chậm (>300ms) = velocity thấp (~40)
    if (_touchStartTime != null) {
      final duration =
          DateTime.now().difference(_touchStartTime!).inMilliseconds;
      final velocityNormalized =
          (1.0 - (duration.clamp(0, 300) / 300.0)).clamp(0.3, 1.0);
      final velocity = (velocityNormalized * 127).round();

      setState(() {
        _velocity = velocityNormalized;
      });

      widget.onNoteOn(velocity);
    }

    setState(() {
      _isPressed = false;
    });

    // Fade out animation
    _fadeController.forward().then((_) {
      widget.onNoteOff();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? AppTheme.padActive;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          final effectiveOpacity = _isPressed ? 1.0 : _fadeAnimation.value;

          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Color.lerp(
                AppTheme.padIdle,
                color,
                effectiveOpacity * _velocity * 0.6,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: Color.lerp(
                  AppTheme.surfaceBorder,
                  color,
                  effectiveOpacity * _velocity,
                )!,
                width: 1.5,
              ),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4 * _velocity),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

