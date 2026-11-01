import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_time.dart';
import '../model/calendar_unit.dart';
import '../model/health_entry.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';
import 'event_draft.dart';

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

/// The whole event [uid] (its series) becomes as [draft] says.
final class ChangeSeries extends CalendarEdit {
  const ChangeSeries(this.uid, this.draft, {required super.at});

  final String uid;
  final EventDraft draft;
}

/// Only the occurrence of series [uid] at [occurrence] becomes as [draft]
/// says (its repeat is not used).
final class ChangeOccurrence extends CalendarEdit {
  const ChangeOccurrence(
    this.uid,
    this.occurrence,
    this.draft, {
    required super.at,
  });

  final String uid;
  final CalendarTime occurrence;
  final EventDraft draft;
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
Calendar applyEdit(Calendar calendar, CalendarEdit edit) {
  final at = edit.at;
  switch (edit) {
    case AddEvent(:final uid, :final draft):
      if (calendar.unitOf(UidKey(uid)) != null) return calendar;
      final event = _drafted(
        Component('VEVENT', [ContentLine('UID', uid)]),
        draft,
        series: true,
      );
      return calendar.withUnit(
        CalendarUnit.edited(UidKey(uid), [_stamped(event, at, first: true)]),
      );
    case ChangeSeries(:final uid, :final draft):
      return _changed(calendar, uid, (event) {
        final series = _drafted(event.series.component, draft, series: true);
        return [
          _stamped(series, at),
          for (final part in event.changed) part.component,
        ];
      });
    case ChangeOccurrence(:final uid, :final occurrence, :final draft):
      return _changed(calendar, uid, (event) {
        final old = event.changedAt(occurrence);
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
        if (event.series.repeat == null) return [_marker(event, at)];
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

/// [calendar] with event [uid]'s components replaced by [change]'s.
Calendar _changed(
  Calendar calendar,
  String uid,
  List<Component> Function(CalendarEvent event) change,
) => switch (calendar.eventOf(uid)) {
  final event? => calendar.withUnit(
    CalendarUnit.edited(event.key, change(event)),
  ),
  null => calendar,
};

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

/// [event] stamped as edited [at]; a [first] stamp starts its `SEQUENCE`
/// at 0.
Component _stamped(Component event, DateTime at, {bool first = false}) {
  final sequence = int.tryParse(event.value('SEQUENCE')?.trim() ?? '') ?? -1;
  return event
      .withProperty('DTSTAMP', stampLine('DTSTAMP', at))
      .withProperty('LAST-MODIFIED', stampLine('LAST-MODIFIED', at))
      .withProperty(
        'SEQUENCE',
        ContentLine('SEQUENCE', '${first ? 0 : sequence + 1}'),
      );
}

/// [event] with what [draft] says where it differs; its repeat only if a
/// [series].
Component _drafted(Component event, EventDraft draft, {required bool series}) {
  final now = EventPart(event);
  final health = draft.health;
  var edited = event
      .withText('SUMMARY', draft.summary, now.summary)
      .withText('DESCRIPTION', draft.description, now.description)
      .withText('LOCATION', draft.location, now.location)
      .withTime('DTSTART', draft.start, now.start)
      .withTime('DTEND', draft.end, now.end);
  if (now.start != draft.start || now.end != draft.end) {
    edited = edited.withProperty('DURATION', null);
  }
  if (series && draft.repeat != now.repeat) {
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
/// entry's.
Component _withHealth(Component event, HealthEntry? entry) {
  bool isHealth(ContentLine line) =>
      (line.name.startsWith('X-TRUCE-') && line.name != 'X-TRUCE-DELETED') ||
      (line.name == 'CATEGORIES' &&
          splitTextList(
            line.value,
          ).any((category) => category.trim().toUpperCase() == healthCategory));
  final kept = [
    for (final line in event.properties)
      if (!isHealth(line)) line,
  ];
  return Component(event.name, [
    ...kept,
    if (entry != null) ...[
      ContentLine('CATEGORIES', '$healthCategory,${entry.kind}'),
      ...entry.values,
    ],
  ], children: event.children);
}

/// [event] with an alert for each of [draft]'s, in place of its own.
Component _withAlerts(Component event, EventDraft draft) => event.withChildren([
  for (final child in event.children)
    if (child.name != 'VALARM') child,
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
