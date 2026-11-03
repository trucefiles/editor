import 'package:flutter/material.dart';

import '../ui/cycle_text.dart';
import 'day_cells.dart';
import 'health_days.dart';

/// What the shown calendars tell about their content, above the views:
/// for each health calendar with periods, where its cycle is [today]
/// (named by [titleOf] when several calendars show), that it is only an
/// estimate, and what the month view's cycle marks mean. Nothing for
/// other calendars yet.
class InsightsStrip<K> extends StatelessWidget {
  const InsightsStrip({
    required this.health,
    required this.today,
    required this.titleOf,
    super.key,
  });

  final HealthDays<K> health;
  final DateTime today;

  /// A calendar's title, to name it; `null` when only one calendar shows.
  final String Function(K calendar)? titleOf;

  @override
  Widget build(BuildContext context) {
    if (!health.any) return const SizedBox.shrink();
    final titleOf = this.titleOf;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(:key, value: cycle) in health.cycles.entries)
            Text(
              [
                if (titleOf != null) titleOf(key),
                cycleText(cycle, today),
              ].join(': '),
              style: theme.bodyMedium,
            ),
          Text(
            'An estimate from the entries, not for contraception.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 4),
          const CycleLegend(),
        ],
      ),
    );
  }
}
