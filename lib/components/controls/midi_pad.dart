import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

/// MIDI Pad - Velocity-sensitive drum pad
/// Hỗ trợ image, tên, custom color, Layer mutual exclusion
class MidiPad extends StatefulWidget {
  final String label;
  /// Callback khi pad được ấn (trả về velocity 0-127)
  final void Function(int velocity) onNoteOn;
  final VoidCallback onNoteOff;
  final Color? customColor;
  final double? size;
  /// URL ảnh từ server
  final String? imageUrl;
  /// Pad này có đang active trong Layer không (dùng cho Layer mutual exclusion)
  final bool isLayerActive;

  const MidiPad({
    super.key,
    required this.label,
    required this.onNoteOn,
    required this.onNoteOff,
    this.customColor,
    this.size,
    this.imageUrl,
    this.isLayerActive = false,
  });

  @override
  State<MidiPad> createState() => _MidiPadState();
}

class _MidiPadState extends State<MidiPad>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  DateTime? _touchStartTime;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(MidiPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khi pad này bị mất active status (pad KHÁC trong cùng Layer được ấn)
    // → isLayerActive chuyển true → false → trigger fade-out
    if (!widget.isLayerActive && oldWidget.isLayerActive) {
      _animCtrl.forward(from: 0.0);
    }
    // Khi pad này nhận lại active status → reset animation
    if (widget.isLayerActive && !oldWidget.isLayerActive) {
      _animCtrl.reset();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _touchStartTime = DateTime.now();
    setState(() => _isPressed = true);
    _animCtrl.reset();
    widget.onNoteOn(127);
  }

  void _onTapUp() {
    if (_touchStartTime != null) {
      _touchStartTime = null;
      setState(() => _isPressed = false);
      _animCtrl.forward().then((_) => widget.onNoteOff());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Để tiện đổi tên biến cho rõ ràng
    final effectiveActive =
        _isPressed || widget.isLayerActive;
    final baseColor = widget.customColor ?? AppTheme.padActive;

    return Listener(
      onPointerDown: (_) => _onTapDown(),
      onPointerUp: (_) => _onTapUp(),
      child: AnimatedBuilder(
        animation: _fadeAnim,
        builder: (context, _) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _buildBgColor(effectiveActive, baseColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: effectiveActive
                    ? baseColor
                    : AppTheme.surfaceBorder,
                width: effectiveActive ? 2.5 : 1.5,
              ),
              boxShadow: effectiveActive
                  ? [
                      BoxShadow(
                        color: baseColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                ? _buildImagePad(baseColor)
                : _buildTextPad(),
          );
        },
      ),
    );
  }

  Color _buildBgColor(bool active, Color color) {
    if (active) {
      return color.withValues(alpha: 0.3);
    }
    return AppTheme.padIdle;
  }

  Widget _buildTextPad() {
    return Center(
      child: Text(
        widget.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildImagePad(Color baseColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Image
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.network(
              widget.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image,
                color: AppTheme.textDim,
                size: 24,
              ),
            ),
          ),
        ),
        // Label
        Positioned(
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 8,
                color: baseColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
