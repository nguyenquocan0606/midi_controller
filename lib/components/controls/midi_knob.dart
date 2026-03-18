import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../constants/app_theme.dart';

/// MIDI Knob - Rotary encoder ảo
/// Kéo lên/xuống hoặc xoay vòng tròn để thay đổi giá trị
class MidiKnob extends StatefulWidget {
  final String label;
  final double value; // 0.0 - 1.0
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final double size;

  const MidiKnob({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.size = 64,
  });

  @override
  State<MidiKnob> createState() => _MidiKnobState();
}

class _MidiKnobState extends State<MidiKnob> {
  double _startY = 0;
  double _startValue = 0;

  void _onPanStart(DragStartDetails details) {
    _startY = details.localPosition.dy;
    _startValue = widget.value;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Kéo lên = tăng, kéo xuống = giảm
    // Sensitivity: kéo 150px = full range
    final delta = (_startY - details.localPosition.dy) / 150.0;
    final newValue = (_startValue + delta).clamp(0.0, 1.0);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? AppTheme.knobArc;
    final midiValue = (widget.value * 127).round();

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      child: SizedBox(
        width: widget.size + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Giá trị
            Text(
              '$midiValue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            // Knob
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _KnobPainter(
                  value: widget.value,
                  activeColor: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter cho knob
class _KnobPainter extends CustomPainter {
  final double value;
  final Color activeColor;

  // Góc bắt đầu và kết thúc của arc (tính bằng radian)
  // 7 giờ → 5 giờ (270 độ sweep)
  static const double _startAngle = 0.75 * math.pi; // 135 độ (7 giờ)
  static const double _sweepAngle = 1.5 * math.pi; // 270 độ

  _KnobPainter({
    required this.value,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final arcWidth = 4.0;

    // Background circle (thân knob)
    canvas.drawCircle(
      center,
      radius - arcWidth - 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.surfaceLight,
            AppTheme.knobBackground,
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius - arcWidth - 2),
        ),
    );

    // Arc background (track)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = AppTheme.faderTrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcWidth
        ..strokeCap = StrokeCap.round,
    );

    // Arc active (giá trị hiện tại)
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle,
        _sweepAngle * value,
        false,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = arcWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Pointer indicator (vạch chỉ hướng trên mặt knob)
    final pointerAngle = _startAngle + _sweepAngle * value;
    final innerRadius = radius - arcWidth - 8;
    final outerRadius = radius - arcWidth - 3;
    final pointerStart = Offset(
      center.dx + innerRadius * 0.5 * math.cos(pointerAngle),
      center.dy + innerRadius * 0.5 * math.sin(pointerAngle),
    );
    final pointerEnd = Offset(
      center.dx + outerRadius * math.cos(pointerAngle),
      center.dy + outerRadius * math.sin(pointerAngle),
    );

    canvas.drawLine(
      pointerStart,
      pointerEnd,
      Paint()
        ..color = AppTheme.knobPointer
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Dot nhỏ ở giữa knob
    canvas.drawCircle(
      center,
      3,
      Paint()..color = activeColor.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.activeColor != activeColor;
}
