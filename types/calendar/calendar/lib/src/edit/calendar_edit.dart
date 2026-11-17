import 'package:collection/collection.dart';

import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_time.dart';
import '../model/calendar_unit.dart';
import '../model/health_entry.dart';
import '../model/item_part.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';
import 'item_draft.dart';
import 'stamp.dart';
import 'zone_block.dart';

/// One edit of a calendar, as the user makes it at [at]: what changes,
/// never file text. Each stamps the event or task it edits
/// (`LAST-MODIFIED` and `DTSTAMP` at [at], `SEQUENCE` one up), which is
/// how a merge tells the newer edit. Each names its item by [key].
sealed class CalendarEdit {
  const CalendarEdit({required this.at});

  final DateTime at;

  /// The event or task it edits (or adds).
  UidKey get key;
}

/// A new event or task [uid] (made unique by the caller), as [draft]
/// says.
final class AddItem extends CalendarEdit {
  const AddItem(this.uid, this.draft, {required super.at});

  final String uid;
  final ItemDraft draft;

  @override
  UidKey get key => draft.keyOf(uid);
}

/// The whole event or task [uid] (its series) becomes as [draft] says,
/// in what the user changed from [from], the draft the form started
/// from; the rest stays as it is now (see [ItemDraft.over]).
final class ChangeSeries extends CalendarEdit {
  const ChangeSeries(
    this.uid,
    this.draft, {
    required this.from,
    required super.at,
  });

  final String uid;
  final ItemDraft draft;
  final ItemDraft from;

  @override
  UidKey get key => draft.keyOf(uid);
}

/// Only the date [occurrence] of series [uid] becomes as [draft] says,
/// in what the user changed from [from], as for [ChangeSeries] (its
/// repeat is not used).
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
  final ItemDraft draft;
  final ItemDraft from;

  @override
  UidKey get key => draft.keyOf(uid);
}

/// Only the date [occurrence] of series [key] goes.
final class DeleteOccurrence extends CalendarEdit {
  const DeleteOccurrence(this.key, this.occurrence, {required super.at});

  @override
  final UidKey key;
  final CalendarTime occurrence;
}

/// The event or task [key] goes, with all its dates: it stays as a
/// marker, so a merge with a text that still has it knows it was
/// deleted.
final class DeleteItem extends CalendarEdit {
  const DeleteItem(this.key, {required super.at});

  @override
  final UidKey key;
}

/// The task [uid], or only its date [date] if it repeats, is checked off
/// ([done]) or open again.
final class CheckTask extends CalendarEdit {
  const CheckTask(this.uid, this.date, {required this.done, required super.at});

  final String uid;

  /// The date of a repeating task; `null` for one that doesn't repeat.
  final CalendarTime? date;
  final bool done;

  @override
  UidKey get key => UidKey.task(uid);
}

/// [calendar] after [edit]; unchanged if the item it names is not there
/// (or already there, for [AddItem]).
Calendar applyEdit(Calendar calendar, CalendarEdit edit) =>
    writeEdit(calendar, edit).calendar;

/// [calendar] after [edit], and the keys of the units it [written]: the
/// item it edits, and the block of each time zone it puts the item in
/// that the calendar has no block for; none if the item it names is not
/// there (or already there, for [AddItem]), or it changes nothing (a
/// check of what is checked already). Every written unit changes: an
/// item is stamped anew, a zone block is new.
({Calendar calendar, List<UnitKey> written}) writeEdit(
  Calendar calendar,
  CalendarEdit edit,
) {
  final units = _written(calendar, edit);
  return (
    calendar: calendar.withUnits(units),
    written: [for (final unit in units) unit.key],
  );
}

List<CalendarUnit> _written(Calendar calendar, CalendarEdit edit) {
  final item = _editedItem(calendar, edit);
  if (item == null) return const [];
  final draft = switch (edit) {
    AddItem(:final draft) ||
    ChangeSeries(:final draft) ||
    ChangeOccurrence(:final draft) => draft,
    DeleteOccurrence() || DeleteItem() || CheckTask() => null,
  };
  return [
    item,
    if (draft != null)
      for (final zone in {for (final time in draft.times) ?time.zone})
        if (!calendar.zones.contains(zone)) ?zoneUnit(zone),
  ];
}

/// The item unit [edit] makes of [calendar]'s; `null` if it makes none.
CalendarUnit? _editedItem(Calendar calendar, CalendarEdit edit) {
  final at = edit.at;
  switch (edit) {
    case AddItem(:final uid, :final draft, :final key):
      if (calendar.unitOf(key) != null) return null;
      final item = _drafted(
        Component(key.component, [
          ContentLine('UID', uid),
          if (draft is TaskDraft) _open,
        ]),
        draft,
        series: true,
      );
      return CalendarUnit.edited(key, [stamped(item, at, first: true)]);
    case ChangeSeries(:final from, :final key):
      return _changed(calendar, key, (item) {
        final now = item.series;
        final draft = _wanted(edit.draft, from, _draftOf(now));
        // A repeat turned off leaves a single item: its left-out, extra
        // and changed dates mean nothing any more.
        if (now.repeat != null && draft.repeat == null) {
          final series = _drafted(
            _withoutDates(now.component),
            draft,
            series: true,
          );
          return [stamped(series, at)];
        }
        final moved = _slotsMoved(now, draft);
        final series = _drafted(
          _withSkippedMoved(now.component, moved),
          draft,
          series: true,
        );
        return [
          stamped(series, at),
          for (final part in item.changed) _withIdMoved(part.component, moved),
        ];
      });
    case ChangeOccurrence(:final occurrence, :final from, :final key):
      return _changed(calendar, key, (item) {
        final old = item.changedAt(occurrence);
        final draft = _wanted(
          edit.draft,
          from,
          (old ?? item.series).anchor == null
              ? null
              : ItemDraft.at(item, occurrence),
        );
        return _withDate(
          item,
          old,
          stamped(
            _drafted(
              old?.component ??
                  _occurrenceOf(item.series.component, occurrence),
              draft,
              series: false,
            ),
            at,
          ),
        );
      });
    case DeleteOccurrence(:final key, :final occurrence):
      return _changed(calendar, key, (item) {
        if (!item.series.repeats) return [markerOf(item, at)];
        final series = item.series.component;
        return [
          stamped(
            Component(series.name, [
              ...series.properties,
              timeLine('EXDATE', occurrence),
            ], children: series.children),
            at,
          ),
          for (final part in item.changed)
            if (part.recurrenceId?.local != occurrence.local) part.component,
        ];
      });
    case DeleteItem(:final key):
      return _changed(calendar, key, (item) => [markerOf(item, at)]);
    case CheckTask(:final uid, :final key, :final date, :final done):
      return switch (calendar.taskOf(uid)) {
        final task? => switch (_checked(task, date, done, at)) {
          final components? => CalendarUnit.edited(key, components),
          null => null,
        },
        null => null,
      };
  }
}

/// [task]'s components once it, or its date [date], is checked off
/// ([done]) or open again at [at]; `null` if it is so already. A date
/// is checked in a changed date of its own (made if there is none); one
/// made open again goes once it is the series' date again.
List<Component>? _checked(
  CalendarTask task,
  CalendarTime? date,
  bool done,
  DateTime at,
) {
  final old = date == null ? null : task.changedAt(date);
  if (date == null || (old == null && !task.series.repeats)) {
    if (task.series.done == done) return null;
    return [
      stamped(_withDone(task.series.component, done, at), at),
      for (final part in task.changed) part.component,
    ];
  }
  if ((old ?? task.series).done == done) return null;
  final changed = _withDone(old?.component ?? _dateOf(task, date), done, at);
  // Open again and as the series has it: no changed date is needed.
  final asSeries =
      !done &&
      !task.series.done &&
      _unchecked(changed) == _unchecked(_dateOf(task, date));
  return _withDate(task, old, asSeries ? null : stamped(changed, at));
}

/// What [part] says now, as a draft; `null` for an event whose times
/// can't be read. A task needs no time.
ItemDraft? _draftOf(ItemPart part) =>
    part is EventPart && part.anchor == null ? null : ItemDraft.of(part);

/// [task]'s date [date] as its series has it, as a changed date.
Component _dateOf(CalendarTask task, CalendarTime date) => _drafted(
  _occurrenceOf(task.series.component, date),
  ItemDraft.of(task.series).dateAt(date),
  series: false,
);

/// [task] checked off ([done]) at [at], or open again.
Component _withDone(Component task, bool done, DateTime at) => task
    .withProperty('STATUS', done ? _completed : _open)
    .withProperty('COMPLETED', done ? stampLine('COMPLETED', at) : null)
    .withProperty(
      'PERCENT-COMPLETE',
      done ? const ContentLine('PERCENT-COMPLETE', '100') : null,
    );

const _open = ContentLine('STATUS', 'NEEDS-ACTION');
const _completed = ContentLine('STATUS', 'COMPLETED');

/// [task]'s text without what checking it writes, nor its edit stamps.
String _unchecked(Component task) => _withDone(task, false, DateTime(0))
    .withProperty('STATUS', null)
    .withProperty('DTSTAMP', null)
    .withProperty('LAST-MODIFIED', null)
    .withProperty('SEQUENCE', null)
    .printed;

/// [item]'s components with [changed] in place of its changed date
/// [old] (`null`: it had none), or added; [old] gone if [changed] is
/// `null`.
List<Component> _withDate(
  CalendarItem item,
  ItemPart? old,
  Component? changed,
) => [
  item.series.component,
  for (final part in item.changed)
    if (part != old) part.component else ?changed,
  if (old == null) ?changed,
];

/// What [draft], from a form started from [from], writes over [now], the
/// item or date as it is now; [draft] itself if [now]'s times can't be
/// read.
ItemDraft _wanted(ItemDraft draft, ItemDraft from, ItemDraft? now) =>
    now == null ? draft : draft.over(from, now);

/// Item [key]'s unit with its components replaced by [change]'s;
/// `null` if [calendar] has no such item.
CalendarUnit? _changed(
  Calendar calendar,
  UidKey key,
  List<Component> Function(CalendarItem item) change,
) => switch (calendar.itemOf(key)) {
  final item? => CalendarUnit.edited(key, change(item)),
  null => null,
};

/// Where a slot of [series] (a date it leaves out, or the date a changed
/// one replaces) goes when the series becomes as [draft] says: moved as
/// its anchor moves, in wall clock, so it stays on the same
/// occurrence; by the start's time of day always, by its days only where
/// the repeat doesn't pick its days itself (a weekly one on Mondays keeps
/// its Mondays); of the new anchor's kind. `null` where nothing moves.
CalendarTime Function(CalendarTime slot)? _slotsMoved(
  ItemPart series,
  ItemDraft draft,
) {
  final (before, after) = (series.anchor, draft.anchor);
  if (before == null || after == null || before == after || !series.repeats) {
    return null;
  }
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
) => switch ((moved, ItemPart.of(part).recurrenceId)) {
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

/// [item] with what [draft] says where it differs; its repeat only if a
/// [series].
Component _drafted(Component item, ItemDraft draft, {required bool series}) {
  final now = ItemPart.of(item);
  var edited = item
      .withText('SUMMARY', draft.summary, now.summary)
      .withText('DESCRIPTION', draft.description, now.description)
      .withText('LOCATION', draft.location, now.location)
      .withText('COLOR', draft.color?.value ?? '', now.color?.value ?? '');
  // The draft's kind is the item's: it reads the item as its kind.
  edited = switch (draft) {
    EventDraft() => _eventDrafted(edited, draft, EventPart(item)),
    TaskDraft() => _taskDrafted(edited, draft, TaskPart(item)),
  };
  // A new anchor writes the repeat's last day anew, as the anchor writes
  // it (RFC 5545 wants an end of the start's kind).
  final anchorChanged = now.anchor != draft.anchor;
  if (series &&
      (draft.repeat != now.repeat ||
          (anchorChanged && draft.repeat?.until != null))) {
    edited = edited.withProperty('RRULE', switch ((
      draft.repeat,
      draft.anchor,
    )) {
      (final repeat?, final anchor?) => ContentLine(
        'RRULE',
        repeat.ruleFor(anchor),
      ),
      _ => null,
    });
  }
  if (!draft.sameAlertsAs(now)) edited = _withAlerts(edited, draft);
  return edited;
}

/// [event] (as [now] reads it) with [draft]'s times and health entry
/// where they differ.
Component _eventDrafted(Component event, EventDraft draft, EventPart now) {
  // A new start or end is written as DTEND; a DURATION would go on from
  // the old one.
  final timesChanged = now.start != draft.start || now.end != draft.end;
  final endWritten = event.property('DTEND') == null ? null : now.end;
  var edited = event
      .withTime('DTSTART', draft.start, now.start)
      .withTime('DTEND', draft.end, timesChanged ? endWritten : now.end);
  if (timesChanged) edited = edited.withProperty('DURATION', null);
  if (draft.health != now.health) edited = _withHealth(edited, draft.health);
  return edited;
}

/// [task] (as [now] reads it) with [draft]'s times where they differ.
Component _taskDrafted(Component task, TaskDraft draft, TaskPart now) {
  // A new due time is written as DUE; a DURATION would go on from the
  // old start.
  final timesChanged = now.due != draft.due || now.start != draft.start;
  final dueWritten = task.property('DUE') == null ? null : now.due;
  final edited = task
      .withTime('DTSTART', draft.start, now.start)
      .withTime('DUE', draft.due, timesChanged ? dueWritten : now.due);
  return timesChanged ? edited.withProperty('DURATION', null) : edited;
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

/// [item] with an alert for each of [draft]'s, in place of the alerts the
/// form shows; other alarms stay (see [alertBefore]). A task's count from
/// its due time (RFC 5545, 3.8.6.3).
Component _withAlerts(Component item, ItemDraft draft) {
  final fromEnd = draft is TaskDraft;
  return item.withChildren([
    for (final child in item.children)
      if (alertBefore(child, fromEnd: fromEnd) == null) child,
    for (final before in draft.alerts)
      Component('VALARM', [
        const ContentLine('ACTION', 'DISPLAY'),
        textLine('DESCRIPTION', draft.summary),
        alertTrigger(before, fromEnd: fromEnd),
      ]),
  ]);
}

extension on Component {
  /// With text property [name] holding [text] if it is not [now]; an
  /// empty text has none.
  Component withText(String name, String text, String now) => text == now
      ? this
      : withProperty(name, text.isEmpty ? null : textLine(name, text));

  /// With time property [name] at [time] (`null`: none) if it is not
  /// [now].
  Component withTime(String name, CalendarTime? time, CalendarTime? now) =>
      time == now
      ? this
      : withProperty(name, time == null ? null : timeLine(name, time));
}
