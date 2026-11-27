import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class ForgettingCurve extends StatelessWidget {
  const ForgettingCurve({
    super.key,
    required this.h,
    required this.elapsedDays,
    required this.intervalDays,
    this.height = 190,
  });

  final double h;
  final double elapsedDays;
  final int intervalDays;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CurvePainter(
          h: h,
          elapsedDays: elapsedDays,
          intervalDays: intervalDays,
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.h,
    required this.elapsedDays,
    required this.intervalDays,
  });

  final double h;
  final double elapsedDays;
  final int intervalDays;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 26.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final maxDays = math.max(math.max(h * 3.2, elapsedDays + intervalDays), 7.0);

    double x(double days) => plot.left + (days / maxDays) * plot.width;
    double y(double retention) => plot.top + (1 - retention) * plot.height;

    final gridPaint = Paint()
      ..color = const Color(0xFFEDEDF5)
      ..strokeWidth = 1;
    for (final value in [0.0, 0.5, 1.0]) {
      canvas.drawLine(
        Offset(plot.left, y(value)),
        Offset(plot.right, y(value)),
        gridPaint,
      );
      _label(
        canvas,
        '${(value * 100).round()}%',
        Offset(0, y(value) - 7),
        const TextStyle(fontSize: 10, color: AppColors.muted),
        width: 32,
        align: TextAlign.right,
      );
    }

    _label(
      canvas,
      '0 天',
      Offset(plot.left, plot.bottom + 6),
      const TextStyle(fontSize: 10, color: AppColors.muted),
    );
    _label(
      canvas,
      '${maxDays.round()} 天',
      Offset(plot.right - 40, plot.bottom + 6),
      const TextStyle(fontSize: 10, color: AppColors.muted),
    );

    final path = Path();
    final fill = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final days = maxDays * i / steps;
      final retention = math.pow(2, -days / math.max(h, 0.1)).toDouble();
      final point = Offset(x(days), y(retention));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        fill.moveTo(plot.left, plot.bottom);
        fill.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        fill.lineTo(point.dx, point.dy);
      }
    }
    fill
      ..lineTo(plot.right, plot.bottom)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.seed.withValues(alpha: 0.22),
            AppColors.seed.withValues(alpha: 0.01),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.seed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final current = math.pow(2, -elapsedDays / math.max(h, 0.1)).toDouble();
    final currentPoint = Offset(x(elapsedDays), y(current));
    final nextDays = elapsedDays + intervalDays;
    final next = math.pow(2, -nextDays / math.max(h, 0.1)).toDouble();
    final nextPoint = Offset(x(nextDays), y(next));

    final dashPaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(currentPoint.dx, plot.top),
      Offset(currentPoint.dx, plot.bottom),
      dashPaint,
    );

    canvas.drawCircle(
      currentPoint,
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      currentPoint,
      5,
      Paint()
        ..color = AppColors.seed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _label(
      canvas,
      '今天',
      Offset(currentPoint.dx - 14, currentPoint.dy - 20),
      const TextStyle(fontSize: 10, color: AppColors.seed, fontWeight: FontWeight.w600),
    );

    canvas.drawCircle(
      nextPoint,
      4,
      Paint()..color = AppColors.amber,
    );
    _label(
      canvas,
      '下次',
      Offset(nextPoint.dx - 12, nextPoint.dy - 18),
      const TextStyle(fontSize: 10, color: AppColors.amber, fontWeight: FontWeight.w600),
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double width = 60,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) =>
      oldDelegate.h != h ||
      oldDelegate.elapsedDays != elapsedDays ||
      oldDelegate.intervalDays != intervalDays;
}

class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final maxValue = counts.fold<int>(1, (value, item) => math.max(value, item));
    final today = DateTime.now();
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(counts.length, (index) {
          final day = today.subtract(Duration(days: counts.length - 1 - index));
          final ratio = counts[index] / maxValue;
          final isToday = index == counts.length - 1;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${counts[index]}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isToday ? AppColors.seed : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 12 + ratio * 62,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.seed
                        : AppColors.seed.withValues(alpha: 0.16 + ratio * 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _weekday(day.weekday),
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _weekday(int value) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return labels[value - 1];
  }
}
