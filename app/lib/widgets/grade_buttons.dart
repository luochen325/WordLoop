import 'package:material_ui/material_ui.dart';

import '../services/scheduler.dart';
import '../theme.dart';

class GradeButtons extends StatelessWidget {
  const GradeButtons({
    super.key,
    required this.onGrade,
    this.busy = false,
    this.compact = true,
  });

  final ValueChanged<ReviewGrade> onGrade;
  final bool busy;
  final bool compact;

  static Color colorFor(ReviewGrade grade) {
    switch (grade) {
      case ReviewGrade.again:
        return AppColors.rose;
      case ReviewGrade.hard:
        return AppColors.amber;
      case ReviewGrade.good:
        return AppColors.seed;
      case ReviewGrade.easy:
        return AppColors.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          for (final grade in ReviewGrade.values) ...[
            if (grade != ReviewGrade.again) const SizedBox(width: 6),
            Expanded(
              child: _button(grade, showDescription: false, height: 38),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _button(ReviewGrade.again, showDescription: true)),
            const SizedBox(width: 8),
            Expanded(child: _button(ReviewGrade.hard, showDescription: true)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _button(ReviewGrade.good, showDescription: true)),
            const SizedBox(width: 8),
            Expanded(child: _button(ReviewGrade.easy, showDescription: true)),
          ],
        ),
      ],
    );
  }

  Widget _button(
    ReviewGrade grade, {
    required bool showDescription,
    double? height,
  }) {
    final color = colorFor(grade);
    return GestureDetector(
      onTap: busy ? null : () => onGrade(grade),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: showDescription ? 9 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: busy ? 0.04 : 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
              showDescription ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              grade.label,
              style: TextStyle(
                fontSize: showDescription ? 14 : 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (showDescription) ...[
              const SizedBox(height: 2),
              Text(
                grade.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
