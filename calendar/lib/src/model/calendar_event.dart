import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';
import 'calendar_time.dart';
import 'calendar_unit.dart';
import 'health_entry.dart';
import 'repeat.dart';

/// What one event component says: the series or single event, or one
/// changed occurrence of a series. Worked out once from its [component].
final class EventPart {
  EventPart(this.component);

  final Component component;

  late final String summary = _text('SUMMARY');
  late final String description = _text('DESCRIPTION');
  late final String location = _text('LOCATION');

  /// When it starts; `null` if that can't be read (it doesn't show).
  late final CalendarTime? start = switch (component.property('DTSTART')) {
    final line? => timeOf(line),
    null => null,
  };

  /// When it ends: its `DTEND`, else its start plus its `DURATION`, else a
  /// day after a day's start, else its start.
  late final CalendarTime? end = _end();

  bool get allDay => start is AllDay;

  /// The occurrence of its series it changes; `null` for the series or a
  /// single event.
  late final CalendarTime? recurrenceId = switch (component.property(
    'RECURRENCE-ID',
  )) {
    final line? => timeOf(line),
    null => null,
  };

  /// How it repeats; `null` if it doesn't.
  late final Repeat? repeat = switch (component.value('RRULE')) {
    final rule? when rule.trim().isNotEmpty => Repeat.of(rule.trim()),
    _ => null,
  };

  /// The occurrences of its series left out.
  late final List<CalendarTime> exdates = [
    for (final line in component.all('EXDATE')) ...timesOf(line),
  ];

  /// When its alerts come, before its start; alerts at other times (e.g.
  /// a fixed time) are kept in the file but not listed.
  late final List<Duration> alerts = [
    for (final alarm in component.children)
      if (alarm.name == 'VALARM')
        if (alarm.property('TRIGGER') case final trigger?
            when trigger.param('VALUE') != 'DATE-TIME' &&
                trigger.param('RELATED') != 'END')
          if (durationOf(trigger.value) case final offset?) -offset,
  ];

  late final List<String> categories = [
    for (final line in component.all('CATEGORIES'))
      ...splitTextList(line.value),
  ];

  /// The health entry it is; `null` if it is none.
  late final HealthEntry? health = HealthEntry.of(component);

  /// Whether it is a deleted event's marker.
  late final bool deleted =
      component.value('X-TRUCE-DELETED')?.trim().toUpperCase() == 'TRUE';

  /// Whether it is cancelled (a deleted event's marker too).
  late final bool cancelled =
      component.value('STATUS')?.trim().toUpperCase() == 'CANCELLED';

  String _text(String name) => unescapeText(component.value(name) ?? '');

  CalendarTime? _end() {
    final start = this.start;
    if (start == null) return null;
    if (component.property('DTEND') case final line?) {
      if (timeOf(line) case final end?) return end;
    }
    if (durationOf(component.value('DURATION') ?? '') case final duration?) {
      return start.at(start.wall.add(duration));
    }
    return start is AllDay
        ? start.at(start.wall.add(const Duration(days: 1)))
        : start;
  }
}

/// One event of a calendar: all components with its [uid], the [series]
/// (or single event) and its changed occurrences ([changed]).
final class CalendarEvent {
  CalendarEvent(this.uid, this.series, this.changed);

  /// The event of [unit]; `null` if it holds none.
  static CalendarEvent? of(CalendarUnit unit) {
    if (unit.key case UidKey(:final uid)) {
      final parts = [
        for (final component in unit.components)
          if (component.name == 'VEVENT') EventPart(component),
      ];
      if (parts.isEmpty) return null;
      final series =
          parts.where((part) => part.recurrenceId == null).firstOrNull ??
          parts.first;
      return CalendarEvent(uid, series, [
        for (final part in parts)
          if (part != series && part.recurrenceId != null) part,
      ]);
    }
    return null;
  }

  final String uid;
  final EventPart series;
  final List<EventPart> changed;

  UnitKey get key => UidKey(uid);

  /// The changed occurrence of the series' occurrence at [occurrence];
  /// `null` if it is not changed.
  EventPart? changedAt(CalendarTime occurrence) => changed
      .where((part) => part.recurrenceId?.local == occurrence.local)
      .firstOrNull;

  /// Its components, the series first.
  List<Component> get components => [
    series.component,
    for (final part in changed) part.component,
  ];
}

/// What the user calls the event of [unit] (its title), for notices.
String nameOfUnit(CalendarUnit unit) => switch (CalendarEvent.of(unit)) {
  final event? when event.series.summary.trim().isNotEmpty =>
    event.series.summary.trim(),
  _ => 'An event',
};
