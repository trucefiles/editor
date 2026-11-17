import '../read/component.dart';
import '../read/content_line.dart';
import 'calendar_time.dart';
import 'calendar_unit.dart';
import 'item_part.dart';
import 'occurrence.dart';

/// One item of a calendar, an event or a task: all components of its
/// kind with its [uid], the [series] (or single item) and the rest
/// ([changed]): its changed dates, and any part whose date can't be read,
/// kept but never shown.
sealed class CalendarItem<P extends ItemPart> {
  CalendarItem(this.uid, this.series, this.changed);

  final String uid;
  final P series;
  final List<P> changed;

  /// The key of its unit.
  UidKey get key;

  /// The changed date of the series' date at [date]; `null` if it is not
  /// changed.
  P? changedAt(CalendarTime date) => changed
      .where((part) => part.recurrenceId?.local == date.local)
      .firstOrNull;

  /// [part] of it shown from [start] to [end] (on this device's clock),
  /// as its date [recurrence] if it repeats: an occurrence of its kind.
  Occurrence occurrenceOf(
    P part, {
    required DateTime start,
    required DateTime end,
    CalendarTime? recurrence,
  });

  /// Its components, the series first.
  List<Component> get components => [
    series.component,
    for (final part in changed) part.component,
  ];
}

/// An event: a series with its changed dates, or one event.
final class CalendarEvent extends CalendarItem<EventPart> {
  CalendarEvent._(super.uid, super.series, super.changed);

  /// The event [uid] of [parts], its series the first that changes no
  /// date (else the first).
  factory CalendarEvent(String uid, List<EventPart> parts) {
    final (series, changed) = _split(parts);
    return CalendarEvent._(uid, series, changed);
  }

  @override
  UidKey get key => UidKey.event(uid);

  @override
  EventOccurrence occurrenceOf(
    EventPart part, {
    required DateTime start,
    required DateTime end,
    CalendarTime? recurrence,
  }) => EventOccurrence(
    this,
    part,
    start: start,
    end: end,
    recurrence: recurrence,
  );
}

/// A task (`VTODO`): a repeating one with its changed (or checked)
/// dates, or one task.
final class CalendarTask extends CalendarItem<TaskPart> {
  CalendarTask._(super.uid, super.series, super.changed);

  /// The task [uid] of [parts], its series as for [CalendarEvent.new].
  factory CalendarTask(String uid, List<TaskPart> parts) {
    final (series, changed) = _split(parts);
    return CalendarTask._(uid, series, changed);
  }

  @override
  UidKey get key => UidKey.task(uid);

  /// A date due at a time shows as the half hour up to it, but not before
  /// that day begins on this device's clock, so it shows on one day only.
  @override
  TaskOccurrence occurrenceOf(
    TaskPart part, {
    required DateTime start,
    required DateTime end,
    CalendarTime? recurrence,
  }) {
    final dayBegins = DateTime(end.year, end.month, end.day);
    return TaskOccurrence(
      this,
      part,
      start: part.allDay || !start.isBefore(dayBegins) ? start : dayBegins,
      end: end,
      recurrence: recurrence,
    );
  }
}

/// [parts] as the series (the first that changes no date, else the
/// first) and the rest.
(P, List<P>) _split<P extends ItemPart>(List<P> parts) {
  final series =
      parts.where((part) => !part.changesOccurrence).firstOrNull ?? parts.first;
  return (
    series,
    [
      for (final part in parts)
        if (part != series) part,
    ],
  );
}

/// What the user calls [unit] (an event's or a task's title), for
/// notices.
String nameOfUnit(CalendarUnit unit) {
  final item = unit.item;
  final named = item?.series.component ?? unit.components.firstOrNull;
  final title = unescapeText(named?.value('SUMMARY') ?? '').trim();
  return title.isNotEmpty
      ? title
      : switch (item) {
          CalendarEvent() => 'An event',
          CalendarTask() => 'A task',
          null => 'An entry',
        };
}
