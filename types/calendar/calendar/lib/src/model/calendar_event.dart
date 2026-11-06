import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';
import 'calendar_time.dart';
import 'calendar_unit.dart';
import 'event_color.dart';
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

  /// Whether it changes one occurrence of its series: it has a
  /// `RECURRENCE-ID`, read or not.
  late final bool changesOccurrence =
      component.property('RECURRENCE-ID') != null;

  /// The occurrence of its series it changes; `null` for the series or a
  /// single event, and where its `RECURRENCE-ID` can't be read.
  late final CalendarTime? recurrenceId = switch (component.property(
    'RECURRENCE-ID',
  )) {
    final line? => timeOf(line),
    null => null,
  };

  /// Its `RRULE` as written, without `RRULE:`; `null` if it doesn't
  /// repeat.
  late final String? rule = switch (component.value('RRULE')?.trim()) {
    final rule? when rule.isNotEmpty => rule,
    _ => null,
  };

  /// How it repeats, as the form shows it; `null` if it doesn't.
  late final Repeat? repeat = switch ((rule, start)) {
    (final rule?, final start?) => Repeat.of(rule, start),
    _ => null,
  };

  /// The occurrences its series has besides its rule's (`RDATE`).
  late final List<CalendarTime> rdates = [
    for (final line in component.all('RDATE')) ...timesOf(line),
  ];

  /// Whether it repeats: by a rule, or by extra dates alone.
  bool get repeats => rule != null || rdates.isNotEmpty;

  /// The occurrences of its series left out.
  late final List<CalendarTime> exdates = [
    for (final line in component.all('EXDATE')) ...timesOf(line),
  ];

  /// When its alerts come, before its start (see [alertBefore]).
  late final List<Duration> alerts = [
    for (final alarm in component.children) ?alertBefore(alarm),
  ];

  late final List<String> categories = [
    for (final line in component.all('CATEGORIES'))
      ...splitTextList(line.value),
  ];

  /// Its own color; `null` if it has none.
  late final EventColor? color = component.value('COLOR') == null
      ? null
      : EventColor(_text('COLOR'));

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

/// How long before its event's start [alarm] comes, if it is an alert the
/// form shows: one shown on screen at a time from the start. Other alarms
/// (a fixed time, from the end, a sound or a mail) are kept in the file
/// but not listed; `null` for them.
Duration? alertBefore(Component alarm) => switch (alarm.property('TRIGGER')) {
  final trigger?
      when alarm.name == 'VALARM' &&
          alarm.value('ACTION')?.trim().toUpperCase() == 'DISPLAY' &&
          trigger.param('VALUE') != 'DATE-TIME' &&
          trigger.param('RELATED') != 'END' =>
    switch (durationOf(trigger.value)) {
      final offset? => -offset,
      null => null,
    },
  _ => null,
};

/// One event of a calendar: all components with its [uid], the [series]
/// (or single event) and the rest ([changed]): its changed occurrences,
/// and any part whose occurrence can't be read, kept but never shown.
final class CalendarEvent {
  CalendarEvent(this.uid, this.series, this.changed);

  /// The event of [unit]; `null` if it holds none.
  static CalendarEvent? of(CalendarUnit unit) {
    if (unit.key case UidKey(component: 'VEVENT', :final uid)) {
      final parts = unit.components.map(EventPart.new).toList();
      final series =
          parts.where((part) => !part.changesOccurrence).firstOrNull ??
          parts.first;
      return CalendarEvent(uid, series, [
        for (final part in parts)
          if (part != series) part,
      ]);
    }
    return null;
  }

  final String uid;
  final EventPart series;
  final List<EventPart> changed;

  UnitKey get key => UidKey.event(uid);

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

/// What the user calls [unit] (an event's or a task's title), for
/// notices.
String nameOfUnit(CalendarUnit unit) {
  final event = CalendarEvent.of(unit);
  final named = event?.series.component ?? unit.components.firstOrNull;
  final title = unescapeText(named?.value('SUMMARY') ?? '').trim();
  return title.isNotEmpty ? title : (event != null ? 'An event' : 'An entry');
}
