import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

/// MIDI Fader - Vertical slider với multi-touch support
/// Dùng Listener (raw pointer) để hỗ trợ kéo nhiều fader cùng lúc
class MidiFader extends StatefulWidget {
  final String label;
  final double value; // 0.0 - 1.0
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final double width;
  final double height;

  const MidiFader({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.width = 60,
    this.height = 250,
  });

  @override
  State<MidiFader> createState() => _MidiFaderState();
}

class _MidiFaderState extends State<MidiFader> {
  int? _activePointer; // Track pointer riêng cho multi-touch

  void _handlePointerEvent(Offset localPosition) {
    final trackHeight = widget.height - 60; // Trừ padding top/bottom
    final clampedY = localPosition.dy.clamp(30.0, trackHeight + 30.0);
    // Đảo ngược: kéo lên = giá trị cao
    final normalized = 1.0 - ((clampedY - 30.0) / trackHeight);
    widget.onChanged(normalized.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? AppTheme.faderThumb;
    final midiValue = (widget.value * 127).round();

    return Listener(
      // Dùng Listener thay vì GestureDetector để hỗ trợ multi-touch
      onPointerDown: (event) {
        _activePointer = event.pointer;
        _handlePointerEvent(event.localPosition);
      },
      onPointerMove: (event) {
        if (event.pointer == _activePointer) {
          _handlePointerEvent(event.localPosition);
        }
      },
      onPointerUp: (event) {
        if (event.pointer == _activePointer) {
          _activePointer = null;
        }
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Column(
          children: [
            // Giá trị MIDI
            Text(
              '$midiValue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
            ),
            const SizedBox(height: 4),
            // Fader track
            Expanded(
              child: CustomPaint(
                size: Size(widget.width, double.infinity),
                painter: _FaderPainter(
                  value: widget.value,
                  activeColor: color,
                ),
              ),
            ),
            const SizedBox(height: 6),
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

/// CustomPainter cho fader track + thumb + LED meter
class _FaderPainter extends CustomPainter {
  final double value;
  final Color activeColor;

  _FaderPainter({
    required this.value,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final trackWidth = 6.0;
    final thumbHeight = 20.0;
    final thumbWidth = size.width * 0.65;
    final meterWidth = 4.0;

    // Track background
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, size.height / 2),
        width: trackWidth,
        height: size.height,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      trackRect,
      Paint()..color = AppTheme.faderTrack,
    );

    // Vị trí thumb (đảo ngược: value 1.0 = top)
    final thumbY = size.height * (1.0 - value);

    // LED Meter (bên trái track)
    final meterX = centerX - trackWidth - 4;
    final meterHeight = size.height - thumbY;
    if (meterHeight > 0) {
      // Gradient từ xanh → vàng → đỏ
      final meterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: const [
            AppTheme.faderMeterLow,
            AppTheme.faderMeterMid,
            AppTheme.faderMeterHigh,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(
          Rect.fromLTWH(meterX, thumbY, meterWidth, meterHeight),
        );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(meterX, thumbY, meterWidth, meterHeight),
          const Radius.circular(2),
        ),
        meterPaint,
      );
    }

    // Tick marks (vạch chia)
    final tickPaint = Paint()
      ..color = AppTheme.textDim.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      final y = size.height * i / 10;
      final tickLength = (i == 0 || i == 5 || i == 10) ? 8.0 : 4.0;
      canvas.drawLine(
        Offset(centerX + trackWidth + 2, y),
        Offset(centerX + trackWidth + 2 + tickLength, y),
        tickPaint,
      );
    }

    // Thumb (nắm kéo)
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, thumbY),
        width: thumbWidth,
        height: thumbHeight,
      ),
      const Radius.circular(4),
    );

    // Thumb shadow
    canvas.drawRRect(
      thumbRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Thumb body
    canvas.drawRRect(
      thumbRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceLight.withValues(alpha: 0.9),
            AppTheme.surface,
          ],
        ).createShader(thumbRect.outerRect),
    );

    // Thumb center line (nét giữa nắm kéo)
    canvas.drawLine(
      Offset(centerX - thumbWidth * 0.25, thumbY),
      Offset(centerX + thumbWidth * 0.25, thumbY),
      Paint()
        ..color = activeColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FaderPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.activeColor != activeColor;
}
