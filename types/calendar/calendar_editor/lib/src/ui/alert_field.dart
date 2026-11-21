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

/// A form's alert: none or one of [alertChoices], picked from a list
/// ([onAlerts] tells a pick); alerts the list doesn't offer show as they
/// are, to keep. [at] names an alert right at the time they count from.
/// Below it, which calendars' alerts ring.
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
    String text(Duration before) => alertText(before, at: at);
    return DropdownButtonFormField<_Alerts>(
      initialValue: _Alerts(alerts),
      decoration: const InputDecoration(
        labelText: 'Alert',
        helperText: 'Rings for the calendars shown in the Calendars tab',
      ),
      items: [
        const DropdownMenuItem(value: _Alerts([]), child: Text('None')),
        if (alerts.isNotEmpty && !_offered(alerts))
          DropdownMenuItem(
            value: _Alerts(alerts),
            child: Text(alerts.map(text).join(', ')),
          ),
        for (final before in alertChoices)
          DropdownMenuItem(value: _Alerts([before]), child: Text(text(before))),
      ],
      onChanged: (picked) => onAlerts(picked?.before ?? const []),
    );
  }

  /// Whether [alerts] is one the list offers.
  static bool _offered(List<Duration> alerts) =>
      alerts.length == 1 && alertChoices.contains(alerts.single);
}

/// The alerts a choice of the form's list stands for, equal by their
/// times (a list alone is equal only to itself).
final class _Alerts {
  const _Alerts(this.before);

  final List<Duration> before;

  static const _equality = ListEquality<Duration>();

  @override
  bool operator ==(Object other) =>
      other is _Alerts && _equality.equals(other.before, before);

  @override
  int get hashCode => _equality.hash(before);
}

/// How an alert [before] the time it counts from reads; [at] names one
/// right at that time.
String alertText(Duration before, {String at = 'At the start'}) =>
    switch (before) {
      Duration.zero => at,
      _ when before.inDays > 0 && before.inHours % 24 == 0 =>
        before.inDays == 1 ? '1 day before' : '${before.inDays} days before',
      _ when before.inMinutes % 60 == 0 =>
        before.inHours == 1
            ? '1 hour before'
            : '${before.inHours} hours before',
      _ => '${before.inMinutes} minutes before',
    };
