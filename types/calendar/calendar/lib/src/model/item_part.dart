import '../alerts/alarm.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';
import 'calendar_time.dart';
import 'calendar_unit.dart' show ItemKind;
import 'event_color.dart';
import 'health_entry.dart';
import 'repeat.dart';

/// What one component of a calendar item says: the series or single
/// item, or one changed date of a series. Worked out once from its
/// [component]. An event's ([EventPart]) or a task's ([TaskPart]); what
/// both share is read here.
sealed class ItemPart {
  ItemPart(this.component);

  /// The part [component] is, by its kind: a task's for a `VTODO`, else
  /// an event's.
  factory ItemPart.of(Component component) =>
      switch (ItemKind.named(component.name)) {
        ItemKind.task => TaskPart(component),
        ItemKind.event || null => EventPart(component),
      };

  final Component component;

  late final String summary = _text('SUMMARY');
  late final String description = _text('DESCRIPTION');
  late final String location = _text('LOCATION');

  /// Its `DTSTART`; `null` if it has none or it can't be read.
  late final CalendarTime? start = switch (component.property('DTSTART')) {
    final line? => timeOf(line),
    null => null,
  };

  /// The time its repeat counts from, and its `RECURRENCE-ID`s name its
  /// dates by; `null` if it has none (it doesn't show).
  CalendarTime? get anchor;

  /// From when it takes time on a calendar; `null` if it takes none.
  CalendarTime? get from;

  /// Up to when it takes time on a calendar; for a day, the day after.
  CalendarTime? get to;

  bool get allDay => from is AllDay;

  /// When its alerts come, before the time they count from (an event's
  /// start, a task's due time; see [alertBefore]).
  List<Duration> get alerts;

  /// Its alarms that ring, as written (the form's [alerts] and others).
  late final List<Alarm> alarms = [
    for (final child in component.children) ?Alarm.of(child),
  ];

  /// Whether it changes one date of its series: it has a
  /// `RECURRENCE-ID`, read or not.
  late final bool changesOccurrence =
      component.property('RECURRENCE-ID') != null;

  /// The date of its series it changes; `null` for the series or a single
  /// item, and where its `RECURRENCE-ID` can't be read.
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
  late final Repeat? repeat = switch ((rule, anchor)) {
    (final rule?, final anchor?) => Repeat.of(rule, anchor),
    _ => null,
  };

  /// The dates its series has besides its rule's (`RDATE`).
  late final List<CalendarTime> rdates = [
    for (final line in component.all('RDATE')) ...timesOf(line),
  ];

  /// Whether it repeats: by a rule, or by extra dates alone.
  bool get repeats => rule != null || rdates.isNotEmpty;

  /// The dates of its series left out.
  late final List<CalendarTime> exdates = [
    for (final line in component.all('EXDATE')) ...timesOf(line),
  ];

  late final List<String> categories = [
    for (final line in component.all('CATEGORIES'))
      ...splitTextList(line.value),
  ];

  /// Its own color; `null` if it has none.
  late final EventColor? color = component.value('COLOR') == null
      ? null
      : EventColor(_text('COLOR'));

  /// Whether it is a deleted item's marker.
  late final bool deleted =
      component.value('X-TRUCE-DELETED')?.trim().toUpperCase() == 'TRUE';

  /// Whether it is cancelled (a deleted item's marker too).
  late final bool cancelled = _status == 'CANCELLED';

  late final String? _status = component.value('STATUS')?.trim().toUpperCase();

  String _text(String name) => unescapeText(component.value(name) ?? '');
}

/// What one event component says.
final class EventPart extends ItemPart {
  EventPart(super.component);

  @override
  CalendarTime? get anchor => start;

  @override
  CalendarTime? get from => start;

  @override
  CalendarTime? get to => end;

  /// When it ends: its `DTEND`, else its start plus its `DURATION`, else a
  /// day after a day's start, else its start.
  late final CalendarTime? end = _end();

  @override
  late final List<Duration> alerts = _alertsOf(alarms, fromEnd: false);

  /// The health entry it is; `null` if it is none.
  late final HealthEntry? health = HealthEntry.of(component);

  CalendarTime? _end() {
    final start = this.start;
    if (start == null) return null;
    if (component.property('DTEND') case final line?) {
      if (timeOf(line) case final end?) return end;
    }
    return _after(start, component) ??
        (start is AllDay
            ? start.at(start.wall.add(const Duration(days: 1)))
            : start);
  }
}

/// What one task component (`VTODO`) says. It shows on a calendar at its
/// due time, as the half hour up to it, or all day on its due day; one
/// without a due time takes no time there.
final class TaskPart extends ItemPart {
  TaskPart(super.component);

  /// When it is due: its `DUE`, else its start plus its `DURATION`;
  /// `null` if neither says.
  late final CalendarTime? due = switch (component.property('DUE')) {
    final line? => timeOf(line),
    null => switch (start) {
      final start? => _after(start, component),
      null => null,
    },
  };

  /// Its start if it has one, else its due time.
  @override
  CalendarTime? get anchor => start ?? due;

  /// Where it shows: on its due day or up to its due time; one without
  /// a due time where it starts.
  late final CalendarTime? _shownAt = due ?? start;

  @override
  late final CalendarTime? from = switch (_shownAt) {
    final AllDay day => day,
    final time? => time.at(taskTileStart(time.wall)),
    null => null,
  };

  @override
  late final CalendarTime? to = switch (_shownAt) {
    final AllDay day => day.at(day.wall.add(const Duration(days: 1))),
    final time => time,
  };

  @override
  late final List<Duration> alerts = _alertsOf(alarms, fromEnd: true);

  /// Whether it is done: by its status; without one, by when it was
  /// done.
  late final bool done = switch (_status) {
    null => component.property('COMPLETED') != null,
    final status => status == 'COMPLETED',
  };

  /// When it was done, if it says.
  late final DateTime? completed = switch (component.property('COMPLETED')) {
    final line? => timeOf(line)?.local,
    null => null,
  };
}

/// Where the tile of a task due at the time [due] starts on a calendar:
/// it shows for a while up to [due].
DateTime taskTileStart(DateTime due) => due.subtract(_taskLength);

/// How long a task with a due time shows on a calendar, up to it.
const _taskLength = Duration(minutes: 30);

/// [start] plus [component]'s `DURATION`; `null` if it has none.
CalendarTime? _after(CalendarTime start, Component component) =>
    switch (durationOf(component.value('DURATION') ?? '')) {
      final duration? => start.at(start.wall.add(duration)),
      null => null,
    };

List<Duration> _alertsOf(List<Alarm> alarms, {required bool fromEnd}) => [
  for (final alarm in alarms) ?alertBefore(alarm, fromEnd: fromEnd),
];

/// How long before its item's start (or, [fromEnd], its end or due time)
/// [alarm] comes, if it is an alert the form shows: one shown on screen
/// at a time from there. Other alarms (a fixed time, from the other end,
/// a sound or a mail) are kept in the file but not listed; `null` for
/// them.
Duration? alertBefore(Alarm? alarm, {required bool fromEnd}) => switch (alarm) {
  RelativeAlarm(:final offset, fromEnd: final end, shows: true)
      when end == fromEnd =>
    -offset,
  _ => null,
};

/// The `TRIGGER` line of an alert [before] its item's start (or,
/// [fromEnd], its due time), as the form writes it.
ContentLine alertTrigger(Duration before, {required bool fromEnd}) =>
    ContentLine(
      'TRIGGER',
      durationText(-before),
      params: fromEnd ? const {'RELATED': 'END'} : const {},
    );
