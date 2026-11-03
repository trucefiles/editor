import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

import 'health_days.dart';

/// How each day of the month view is shaded: weekends lightly, and the
/// cycle days of [health] as [CycleLegend] explains them.
MonthDayCellBuilder dayCells(HealthDays<Object?> health) => (context, details) {
  final colors = Theme.of(context).colorScheme;
  final day = health.of(details.date);
  final weekend = details.date.weekday >= DateTime.saturday;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: switch (day) {
        (period: true, likelyPeriod: _, fertile: _) => colors.errorContainer,
        (period: _, likelyPeriod: _, fertile: true) => colors.tertiaryContainer,
        _ when weekend => colors.onSurface.withValues(alpha: 0.04),
        _ => null,
      },
      border: day.likelyPeriod
          ? Border.all(color: colors.error, width: 2)
          : null,
    ),
  );
};

/// What the cycle marks of the month view mean.
class CycleLegend extends StatelessWidget {
  const CycleLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    Widget item(BoxDecoration look, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: look),
        const SizedBox(width: 4),
        Text(text, style: small),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(BoxDecoration(color: colors.errorContainer), 'Period'),
        item(
          BoxDecoration(border: Border.all(color: colors.error, width: 2)),
          'Likely next period',
        ),
        item(BoxDecoration(color: colors.tertiaryContainer), 'Likely fertile'),
      ],
    );
  }
}
