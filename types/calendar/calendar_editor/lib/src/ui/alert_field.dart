import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// The alerts the form offers, before the time they count from.
const alertChoices = [
  Duration.zero,
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(days: 1),
];

/// A form's alerts, each picked from [alertChoices] or, if the list
/// doesn't offer it, shown as it is, to keep; one can be added or
/// removed ([onAlerts] tells the new list). An alert's list leaves out
/// the times other alerts have. [at] names an alert right at the time
/// they count from. Below them, which calendars' alerts ring.
class AlertField extends StatelessWidget {
  const AlertField({
    required this.alerts,
    required this.onAlerts,
    this.at = 'At the start',
    super.key,
  });

  final List<Duration> alerts;
  final ValueChanged<List<Duration>> onAlerts;
  final String at;

  @override
  Widget build(BuildContext context) {
    final unused = alertChoices.whereNot(alerts.contains).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, before) in alerts.indexed)
          _AlertRow(
            before: before,
            offered: {...alertChoices, before}
                .where((choice) => choice == before || !alerts.contains(choice))
                .sorted(),
            at: at,
            onPicked: (picked) => onAlerts([
              for (final (other, alert) in alerts.indexed)
                other == index ? picked : alert,
            ]),
            onRemove: () => onAlerts([
              for (final (other, alert) in alerts.indexed)
                if (other != index) alert,
            ]),
          ),
        if (unused.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Add alert'),
            onPressed: () => onAlerts([...alerts, unused.first]),
          ),
        Text(
          'Rings for the calendars shown in the Calendars tab',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// One alert of an [AlertField]: picked from [offered], or removed.
class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.before,
    required this.offered,
    required this.at,
    required this.onPicked,
    required this.onRemove,
  });

  final Duration before;
  final List<Duration> offered;
  final String at;
  final ValueChanged<Duration> onPicked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<Duration>(
          initialValue: before,
          decoration: const InputDecoration(labelText: 'Alert'),
          items: [
            for (final choice in offered)
              DropdownMenuItem(
                value: choice,
                child: Text(alertText(choice, at: at)),
              ),
          ],
          onChanged: (picked) {
            if (picked != null) onPicked(picked);
          },
        ),
      ),
      IconButton(
        tooltip: 'Remove alert',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    ],
  );
}

/// How an alert [before] the time it counts from reads (a negative one
/// rings after it); [at] names one right at that time.
String alertText(Duration before, {String at = 'At the start'}) {
  if (before == Duration.zero) return at;
  final side = before.isNegative ? 'after' : 'before';
  final length = before.abs();
  String count(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';
  final amount = switch (length) {
    _ when length.inDays > 0 && length.inHours % 24 == 0 => count(
      length.inDays,
      'day',
    ),
    _ when length.inMinutes % 60 == 0 => count(length.inHours, 'hour'),
    _ => count(length.inMinutes, 'minute'),
  };
  return '$amount $side';
}
