import 'package:collection/collection.dart';

import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_time.dart';
import '../model/item_part.dart';
import '../recurrence/occurrences.dart';
import 'alarm.dart';

/// One time an alarm rings: for one date of an event or of an open task.
final class Alert {
  const Alert({
    required this.key,
    required this.at,
    required this.item,
    required this.part,
    this.recurrence,
    this.start,
    this.end,
  });

  /// Tells it apart from the calendar's other alerts, across reads: its
  /// item, date and trigger.
  final String key;

  /// When it rings (UTC).
  final DateTime at;

  final CalendarItem item;

  /// The part of [item] that holds its date.
  final ItemPart part;

  /// Which date of a repeating item it is for, as the series writes it;
  /// `null` for one that doesn't repeat.
  final CalendarTime? recurrence;

  /// When its date starts and ends (a task's: when it is due) on this
  /// device's clock; `null` for a task without a due date.
  final DateTime? start;
  final DateTime? end;

  String get title => part.summary;
}

/// The alerts of [calendar]'s events and open tasks that ring from [from]
/// to [to] (excluded), by time: every alarm that shows or sounds, counted
/// from its date's start, end or due time, or at its own fixed time;
/// deleted, cancelled and done ones left out.
List<Alert> alertsIn(Calendar calendar, DateTime from, DateTime to) {
  bool within(DateTime at) => !at.isBefore(from) && at.isBefore(to);
  final parts = [
    for (final item in calendar.items)
      for (final part in [item.series, ...item.changed])
        if (part.alarms.isNotEmpty) (item: item, part: part),
  ];
  if (parts.isEmpty) return const [];
  // How far from the time it shows each alarm rings.
  final offsets = [
    for (final (item: _, :part) in parts)
      for (final alarm in part.alarms.whereType<RelativeAlarm>())
        alarm.fromEnd ? alarm.offset : alarm.offset - _startGap(part),
  ];
  // A date counts if it shows where its alarms ring from: as far back as
  // the latest alarm after it, as far on as the earliest before it.
  final latest = offsets.fold(Duration.zero, _longer);
  final earliest = offsets.fold(Duration.zero, _shorter);
  final relative = [
    if (offsets.isNotEmpty)
      for (final occurrence in occurrences(
        calendar,
        from.subtract(latest),
        to.subtract(earliest),
      ))
        if (_rings(occurrence.part, occurrence))
          for (final alarm in occurrence.part.alarms.whereType<RelativeAlarm>())
            if (_relativeAlert(occurrence, alarm) case final alert
                when within(alert.at))
              alert,
  ];
  final absolute = [
    for (final (:item, :part) in parts)
      if (_rings(part, null))
        for (final alarm in part.alarms.whereType<AbsoluteAlarm>())
          if (within(alarm.at)) _absoluteAlert(item, part, alarm),
  ];
  return [
    ...{
      for (final alert in [...relative, ...absolute]) alert.key: alert,
    }.values,
  ].sortedBy((alert) => alert.at);
}

Duration _longer(Duration a, Duration b) => a > b ? a : b;

Duration _shorter(Duration a, Duration b) => a < b ? a : b;

/// How long [part] starts before the time it shows by: a task's start
/// before its due time; none for an event.
Duration _startGap(ItemPart part) => switch (part) {
  TaskPart(:final start?, :final due?) => due.local.difference(start.local),
  _ => Duration.zero,
};

/// Whether [part] rings at all: not deleted or cancelled, and for a task
/// (its [occurrence]'s date, if given) not done.
bool _rings(ItemPart part, Occurrence? occurrence) =>
    !part.deleted &&
    !part.cancelled &&
    switch ((part, occurrence)) {
      (_, final TaskOccurrence date) => !date.done,
      (final TaskPart task, null) => !task.done,
      _ => true,
    };

Alert _relativeAlert(Occurrence occurrence, RelativeAlarm alarm) {
  final (start, end) = switch (occurrence) {
    EventOccurrence(:final start, :final end) => (start, end),
    final TaskOccurrence task => (task.due, task.due),
  };
  final base = switch ((occurrence, alarm.fromEnd)) {
    (_, true) => end,
    (final TaskOccurrence task, false) => _taskStart(task),
    (_, false) => start,
  };
  return Alert(
    key: _keyOf(occurrence.item, occurrence.recurrence, alarm),
    at: alarm.ringsAt(base).toUtc(),
    item: occurrence.item,
    part: occurrence.part,
    recurrence: occurrence.recurrence,
    start: start,
    end: end,
  );
}

/// When a task's date starts, for an alarm counted from its start: as
/// long before its due time as its start is before its due; its due time
/// if it has no start.
DateTime _taskStart(TaskOccurrence date) =>
    date.due.subtract(_startGap(date.part));

/// The alert of [alarm], at its own time, for [part] of [item] as it is
/// written: a changed date's own, else the item's first date.
Alert _absoluteAlert(CalendarItem item, ItemPart part, AbsoluteAlarm alarm) {
  final recurrence = part.recurrenceId ?? (part.repeats ? part.anchor : null);
  final (start, end) = switch (part) {
    TaskPart(:final due?) => (due.local, due.local),
    TaskPart() => (null, null),
    EventPart(:final from, :final to) => (from?.local, to?.local),
  };
  return Alert(
    // One alert, whichever dates were changed: other apps copy the alarm
    // into each.
    key: _keyOf(item, null, alarm),
    at: alarm.at,
    item: item,
    part: part,
    recurrence: recurrence,
    start: start,
    end: end,
  );
}

String _keyOf(CalendarItem item, CalendarTime? recurrence, Alarm alarm) => [
  item.key.component,
  item.uid,
  recurrence?.local.toUtc().toIso8601String() ?? '',
  alarm.trigger,
].join('|');
