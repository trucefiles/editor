import '../read/component.dart';
import '../read/content_line.dart';
import 'calendar_time.dart';
import 'calendar_unit.dart';
import 'item_part.dart';

/// The kinds of component a [CalendarItem] is: events and tasks.
const itemKinds = {'VEVENT', 'VTODO'};

/// One item of a calendar, an event or a task: all components of its
/// kind with its [uid], the [series] (or single item) and the rest
/// ([changed]): its changed dates, and any part whose date can't be read,
/// kept but never shown.
sealed class CalendarItem<P extends ItemPart> {
  CalendarItem(this.uid, this.series, this.changed);

  /// The item of [unit]; `null` if it holds none.
  static CalendarItem? of(CalendarUnit unit) => switch (unit.key) {
    UidKey(component: 'VEVENT', :final uid) => CalendarEvent(
      uid,
      unit.components.map(EventPart.new).toList(),
    ),
    UidKey(component: 'VTODO', :final uid) => CalendarTask(
      uid,
      unit.components.map(TaskPart.new).toList(),
    ),
    _ => null,
  };

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
  final item = CalendarItem.of(unit);
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
