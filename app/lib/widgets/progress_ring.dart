import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.centerLabel,
    required this.centerValue,
    this.size = 132,
    this.color = Colors.white,
    this.trackColor = const Color(0x33FFFFFF),
  });

  final double value;
  final String centerValue;
  final String centerLabel;
  final double size;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1),
          color: color,
          trackColor: trackColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.075;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -math.pi / 2,
      math.pi * 2,
      false,
      paint,
    );

    if (value <= 0) return;
    paint.color = color;
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
