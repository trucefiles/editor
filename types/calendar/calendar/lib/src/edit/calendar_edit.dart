import 'dart:math';

import 'package:collection/collection.dart';

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_time.dart';
import '../model/calendar_unit.dart';
import '../model/health_entry.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';
import 'event_draft.dart';
import 'zone_block.dart';

/// One edit of a calendar, as the user makes it at [at]: what changes,
/// never file text. Each stamps the event it edits (`LAST-MODIFIED` and
/// `DTSTAMP` at [at], `SEQUENCE` one up), which is how a merge tells the
/// newer edit.
sealed class CalendarEdit {
  const CalendarEdit({required this.at});

  final DateTime at;
}

/// A new event [uid] (made unique by the caller), as [draft] says.
final class AddEvent extends CalendarEdit {
  const AddEvent(this.uid, this.draft, {required super.at});

  final String uid;
  final EventDraft draft;
}

/// The whole event [uid] (its series) becomes as [draft] says, in what
/// the user changed from [from], the draft the form started from; the
/// rest stays as the event is now (see [EventDraft.over]).
final class ChangeSeries extends CalendarEdit {
  const ChangeSeries(
    this.uid,
    this.draft, {
    required this.from,
    required super.at,
  });

  final String uid;
  final EventDraft draft;
  final EventDraft from;
}

/// Only the occurrence of series [uid] at [occurrence] becomes as [draft]
/// says, in what the user changed from [from], as for [ChangeSeries]
/// (its repeat is not used).
final class ChangeOccurrence extends CalendarEdit {
  const ChangeOccurrence(
    this.uid,
    this.occurrence,
    this.draft, {
    required this.from,
    required super.at,
  });

  final String uid;
  final CalendarTime occurrence;
  final EventDraft draft;
  final EventDraft from;
}

/// Only the occurrence of series [uid] at [occurrence] goes.
final class DeleteOccurrence extends CalendarEdit {
  const DeleteOccurrence(this.uid, this.occurrence, {required super.at});

  final String uid;
  final CalendarTime occurrence;
}

/// The event [uid] goes, with all its occurrences: it stays as a marker,
/// so a merge with a text that still has it knows it was deleted.
final class DeleteEvent extends CalendarEdit {
  const DeleteEvent(this.uid, {required super.at});

  final String uid;
}

/// [calendar] after [edit]; unchanged if the event it names is not there
/// (or already there, for [AddEvent]).
Calendar applyEdit(Calendar calendar, CalendarEdit edit) =>
    calendar.withUnits(editedUnits(calendar, edit));

/// The units [edit] writes into [calendar]: the event it edits, and the
/// block of each time zone it puts the event in that the calendar has no
/// block for; none if the event it names is not there (or already there,
/// for [AddEvent]).
List<CalendarUnit> editedUnits(Calendar calendar, CalendarEdit edit) {
  final event = _editedEvent(calendar, edit);
  if (event == null) return const [];
  final draft = switch (edit) {
    AddEvent(:final draft) ||
    ChangeSeries(:final draft) ||
    ChangeOccurrence(:final draft) => draft,
    DeleteOccurrence() || DeleteEvent() => null,
  };
  return [
    event,
    if (draft != null)
      for (final zone in {
        for (final time in [draft.start, draft.end])
          if (time case Zoned(:final zone)) zone,
      })
        if (!calendar.zones.contains(zone))
          if (zoneBlock(zone) case final block?)
            CalendarUnit.edited(ZoneKey(zone), [block]),
  ];
}

/// The event unit [edit] makes of [calendar]'s; `null` if it makes none.
CalendarUnit? _editedEvent(Calendar calendar, CalendarEdit edit) {
  final at = edit.at;
  switch (edit) {
    case AddEvent(:final uid, :final draft):
      if (calendar.unitOf(UidKey.event(uid)) != null) return null;
      final event = _drafted(
        Component('VEVENT', [ContentLine('UID', uid)]),
        draft,
        series: true,
      );
      return CalendarUnit.edited(UidKey.event(uid), [
        _stamped(event, at, first: true),
      ]);
    case ChangeSeries(:final uid, :final from):
      return _changed(calendar, uid, (event) {
        final now = event.series;
        final draft = _wanted(
          edit.draft,
          from,
          now.start == null ? null : EventDraft.of(now),
        );
        // A repeat turned off leaves a single event: its left-out, extra
        // and changed dates mean nothing any more.
        if (event.series.repeat != null && draft.repeat == null) {
          final series = _drafted(
            _withoutDates(event.series.component),
            draft,
            series: true,
          );
          return [_stamped(series, at)];
        }
        final moved = _slotsMoved(event.series, draft);
        final series = _drafted(
          _withSkippedMoved(event.series.component, moved),
          draft,
          series: true,
        );
        return [
          _stamped(series, at),
          for (final part in event.changed) _withIdMoved(part.component, moved),
        ];
      });
    case ChangeOccurrence(:final uid, :final occurrence, :final from):
      return _changed(calendar, uid, (event) {
        final old = event.changedAt(occurrence);
        final draft = _wanted(
          edit.draft,
          from,
          (old ?? event.series).start == null
              ? null
              : EventDraft.at(event, occurrence),
        );
        final changed = _stamped(
          _drafted(
            old?.component ?? _occurrenceOf(event.series.component, occurrence),
            draft,
            series: false,
          ),
          at,
        );
        return [
          event.series.component,
          for (final part in event.changed)
            part == old ? changed : part.component,
          if (old == null) changed,
        ];
      });
    case DeleteOccurrence(:final uid, :final occurrence):
      return _changed(calendar, uid, (event) {
        if (!event.series.repeats) return [_marker(event, at)];
        final series = event.series.component;
        return [
          _stamped(
            Component(series.name, [
              ...series.properties,
              timeLine('EXDATE', occurrence),
            ], children: series.children),
            at,
          ),
          for (final part in event.changed)
            if (part.recurrenceId?.local != occurrence.local) part.component,
        ];
      });
    case DeleteEvent(:final uid):
      return _changed(calendar, uid, (event) => [_marker(event, at)]);
  }
}

/// What [draft], from a form started from [from], writes over [now], the
/// event or occurrence as it is now; [draft] itself if [now]'s times
/// can't be read.
EventDraft _wanted(EventDraft draft, EventDraft from, EventDraft? now) =>
    now == null ? draft : draft.over(from, now);

/// Event [uid]'s unit with its components replaced by [change]'s;
/// `null` if [calendar] has no such event.
CalendarUnit? _changed(
  Calendar calendar,
  String uid,
  List<Component> Function(CalendarEvent event) change,
) => switch (calendar.eventOf(uid)) {
  final event? => CalendarUnit.edited(event.key, change(event)),
  null => null,
};

/// Where a slot of [series] (a date it leaves out, or the occurrence a
/// changed one replaces) goes when the series becomes as [draft] says:
/// moved as its start moves, in wall clock, so it stays on the same
/// occurrence; by the start's time of day always, by its days only where
/// the repeat doesn't pick its days itself (a weekly one on Mondays keeps
/// its Mondays); of the new start's kind. `null` where nothing moves.
CalendarTime Function(CalendarTime slot)? _slotsMoved(
  EventPart series,
  EventDraft draft,
) {
  final (before, after) = (series.start, draft.start);
  if (before == null || before == after || !series.repeats) return null;
  final days = draft.repeat?.fixesDays ?? false
      ? 0
      : _dayOf(after.wall).difference(_dayOf(before.wall)).inDays;
  final time = _sinceMidnight(after.wall) - _sinceMidnight(before.wall);
  return (slot) {
    // A slot written another way than the start is read on its clock.
    final wall = before.at(slot.wall) == slot
        ? slot.wall
        : before.sameKindAt(slot.local).wall;
    return after.at(
      DateTime.utc(
        wall.year,
        wall.month,
        wall.day + days,
        wall.hour,
        wall.minute,
        wall.second,
      ).add(time),
    );
  };
}

DateTime _dayOf(DateTime wall) => DateTime.utc(wall.year, wall.month, wall.day);

Duration _sinceMidnight(DateTime wall) => wall.difference(_dayOf(wall));

/// [series] with the dates it leaves out moved by [moved]; as it is if
/// [moved] is `null`. A line that can't be read stays as written.
Component _withSkippedMoved(
  Component series,
  CalendarTime Function(CalendarTime slot)? moved,
) => moved == null
    ? series
    : Component(series.name, [
        for (final line in series.properties)
          if (line.name == 'EXDATE' && timesOf(line).isNotEmpty)
            timesLine('EXDATE', timesOf(line).map(moved).toList())
          else
            line,
      ], children: series.children);

/// A changed occurrence [part] naming the occurrence it replaces where
/// [moved] puts it; as it is if [moved] is `null`.
Component _withIdMoved(
  Component part,
  CalendarTime Function(CalendarTime slot)? moved,
) => switch ((moved, EventPart(part).recurrenceId)) {
  (final moved?, final id?) => part.withProperty(
    'RECURRENCE-ID',
    timeLine('RECURRENCE-ID', moved(id)),
  ),
  _ => part,
};

/// [series] without the dates of a repeat: those it leaves out and those
/// it adds.
Component _withoutDates(Component series) => Component(series.name, [
  for (final line in series.properties)
    if (line.name != 'EXDATE' && line.name != 'RDATE') line,
], children: series.children);

/// A deleted [event]'s marker: its id, stamps, start and title, and that
/// it is deleted.
Component _marker(CalendarEvent event, DateTime at) {
  final series = event.series.component;
  return _stamped(
    Component('VEVENT', [
      ContentLine('UID', event.uid),
      ?series.property('DTSTART'),
      ?series.property('SUMMARY'),
      ?series.property('SEQUENCE'),
      const ContentLine('STATUS', 'CANCELLED'),
      const ContentLine('X-TRUCE-DELETED', 'TRUE'),
    ]),
    at,
  );
}

/// A changed occurrence of [series] at [occurrence], before the draft:
/// the series without its repeat, naming the occurrence it changes.
Component _occurrenceOf(Component series, CalendarTime occurrence) {
  const notInOccurrence = {'RRULE', 'RDATE', 'EXDATE', 'EXRULE'};
  return Component(
    series.name,
    [
      for (final line in series.properties)
        if (!notInOccurrence.contains(line.name)) line,
    ],
    children: series.children,
  ).withProperty('RECURRENCE-ID', timeLine('RECURRENCE-ID', occurrence));
}

/// [back], the calendar an undo or redo brings back over [now], as an
/// edit at [at]: each of its events stamped anew where it differs from
/// [now]'s, and each event only [now] has deleted (see [unitsBroughtBack]).
Calendar broughtBack(Calendar back, Calendar now, DateTime at) =>
    back.withUnits([
      for (final event in back.events)
        ?_cameBack(event.key, back.unitOf(event.key), now, at),
      for (final event in now.events)
        if (back.eventOf(event.uid) == null)
          ?_cameBack(event.key, null, now, at),
    ]);

/// [now] with the units [back] holds (by key; `null` for a unit the edit
/// undone or redone added) brought back as an edit at [at]: an event
/// that differs from [now]'s is stamped anew, its `SEQUENCE` above both;
/// an event [back] has not is deleted (a marker); any other unit comes
/// back as it was, but one [back] has not stays (a time zone block may
/// still be named by a marker). So a merge with [now]'s text, e.g. as
/// another device got it, keeps what came back.
Calendar unitsBroughtBack(
  Calendar now,
  Map<UnitKey, CalendarUnit?> back,
  DateTime at,
) => now.withUnits([
  for (final MapEntry(:key, :value) in back.entries)
    ?_cameBack(key, value, now, at),
]);

/// The unit [key] as it comes back to [now] as [back] (`null`: gone) at
/// [at] (see [unitsBroughtBack]); `null` if [now] keeps its own.
CalendarUnit? _cameBack(
  UnitKey key,
  CalendarUnit? back,
  Calendar now,
  DateTime at,
) {
  final current = now.unitOf(key);
  if (back == null) {
    return switch (current == null ? null : CalendarEvent.of(current)) {
      final event? => CalendarUnit.edited(key, [_marker(event, at)]),
      null => null,
    };
  }
  if (back.text == current?.text) return null;
  if (CalendarEvent.of(back) == null) return back;
  final above = current?.components.map(_sequenceOf).fold<int>(-1, max) ?? -1;
  return CalendarUnit.edited(key, [
    for (final component in back.components)
      _stamped(component, at, above: above),
  ]);
}

/// [event] stamped as edited [at]; a [first] stamp starts its `SEQUENCE`
/// at 0, else it goes one above its own and [above].
Component _stamped(
  Component event,
  DateTime at, {
  bool first = false,
  int above = -1,
}) => event
    .withProperty('DTSTAMP', stampLine('DTSTAMP', at))
    .withProperty('LAST-MODIFIED', stampLine('LAST-MODIFIED', at))
    .withProperty(
      'SEQUENCE',
      ContentLine(
        'SEQUENCE',
        '${first ? 0 : max(_sequenceOf(event), above) + 1}',
      ),
    );

/// The `SEQUENCE` of [event]; -1 if it has none.
int _sequenceOf(Component event) =>
    int.tryParse(event.value('SEQUENCE')?.trim() ?? '') ?? -1;

/// [event] with what [draft] says where it differs; its repeat only if a
/// [series].
Component _drafted(Component event, EventDraft draft, {required bool series}) {
  final now = EventPart(event);
  final health = draft.health;
  // A new start or end is written as DTEND; a DURATION would go on from
  // the old one.
  final timesChanged = now.start != draft.start || now.end != draft.end;
  final endWritten = event.property('DTEND') == null ? null : now.end;
  var edited = event
      .withText('SUMMARY', draft.summary, now.summary)
      .withText('DESCRIPTION', draft.description, now.description)
      .withText('LOCATION', draft.location, now.location)
      .withText('COLOR', draft.color?.value ?? '', now.color?.value ?? '')
      .withTime('DTSTART', draft.start, now.start)
      .withTime('DTEND', draft.end, timesChanged ? endWritten : now.end);
  if (timesChanged) edited = edited.withProperty('DURATION', null);
  // A new start writes the repeat's last day anew, as the start writes
  // it (RFC 5545 wants an end of the start's kind).
  final startChanged = now.start != draft.start;
  if (series &&
      (draft.repeat != now.repeat ||
          (startChanged && draft.repeat?.until != null))) {
    edited = edited.withProperty('RRULE', switch (draft.repeat) {
      final repeat? => ContentLine('RRULE', repeat.ruleFor(draft.start)),
      null => null,
    });
  }
  if (health != now.health) edited = _withHealth(edited, health);
  if (!draft.sameAlertsAs(now)) edited = _withAlerts(edited, draft);
  return edited;
}

/// [event] holding [entry]'s tag and values instead of any other health
/// entry's; its other categories stay.
Component _withHealth(Component event, HealthEntry? entry) {
  final tags = healthTagsOf(event);
  bool isTag(String category) => switch (category.trim().toUpperCase()) {
    healthCategory => tags.health,
    final other => other == tags.kind,
  };
  bool isValue(ContentLine line) =>
      line.name.startsWith('X-TRUCE-') && line.name != 'X-TRUCE-DELETED';
  return Component(event.name, [
    for (final line in event.properties)
      if (line.name == 'CATEGORIES')
        ?_withoutCategories(line, isTag)
      else if (!isValue(line))
        line,
    if (entry != null) ...[
      ContentLine('CATEGORIES', '$healthCategory,${entry.kind}'),
      ...entry.values,
    ],
  ], children: event.children);
}

/// [line], a `CATEGORIES` line, without the categories [drop] names: as it
/// is if it has none of them, `null` if nothing is left.
ContentLine? _withoutCategories(
  ContentLine line,
  bool Function(String category) drop,
) {
  final categories = splitTextList(line.value);
  final kept = categories.whereNot(drop).toList();
  if (kept.length == categories.length) return line;
  if (kept.isEmpty) return null;
  return ContentLine(
    'CATEGORIES',
    kept.map(escapeText).join(','),
    params: line.params,
  );
}

/// [event] with an alert for each of [draft]'s, in place of the alerts the
/// form shows; other alarms stay (see [alertBefore]).
Component _withAlerts(Component event, EventDraft draft) => event.withChildren([
  for (final child in event.children)
    if (alertBefore(child) == null) child,
  for (final before in draft.alerts)
    Component('VALARM', [
      const ContentLine('ACTION', 'DISPLAY'),
      textLine('DESCRIPTION', draft.summary),
      ContentLine('TRIGGER', durationText(-before)),
    ]),
]);

extension on Component {
  /// With text property [name] holding [text] if it is not [now]; an
  /// empty text has none.
  Component withText(String name, String text, String now) => text == now
      ? this
      : withProperty(name, text.isEmpty ? null : textLine(name, text));

  /// With time property [name] at [time] if it is not [now].
  Component withTime(String name, CalendarTime time, CalendarTime? now) =>
      time == now ? this : withProperty(name, timeLine(name, time));
}
