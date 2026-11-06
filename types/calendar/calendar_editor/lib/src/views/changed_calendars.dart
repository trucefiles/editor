import 'package:truce_calendar/truce_calendar.dart';

/// The keys of the calendars that show other days in [after] than in
/// [before] ([Calendar.showsSameDaysAs]), or are only in one of them.
Set<K> changedCalendars<K>(Map<K, Calendar> before, Map<K, Calendar> after) => {
  for (final key in {...before.keys, ...after.keys})
    if (!_sameDays(before[key], after[key])) key,
};

bool _sameDays(Calendar? a, Calendar? b) => switch ((a, b)) {
  (null, null) => true,
  (final a?, final b?) => a.showsSameDaysAs(b),
  _ => false,
};
