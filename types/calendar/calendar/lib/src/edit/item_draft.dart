import 'package:collection/collection.dart';

import '../model/calendar_item.dart';
import '../model/calendar_time.dart';
import '../model/calendar_unit.dart';
import '../model/event_color.dart';
import '../model/health_entry.dart';
import '../model/item_part.dart';
import '../model/repeat.dart';
import '../model/wall_on.dart';

/// What an event or a task is to be, as its form states it: never file
/// text. An edit writes only what differs from the item it goes over;
/// everything else of it stays as it was. What both kinds share is here.
sealed class ItemDraft {
  const ItemDraft({
    required this.summary,
    this.description = '',
    this.location = '',
    this.repeat,
    this.alerts = const [],
    this.color,
  });

  /// What [part] says now, to start a form from.
  static ItemDraft of(ItemPart part) => switch (part) {
    EventPart() => EventDraft.of(part),
    TaskPart() => TaskDraft.of(part),
  };

  /// What [item]'s date [date] says now, to start a form from: its changed
  /// one, else the series moved to that date (it doesn't repeat).
  static ItemDraft at(CalendarItem item, CalendarTime date) =>
      switch (item.changedAt(date)) {
        final changed? => of(changed),
        null => of(item.series).dateAt(date),
      };

  final String summary;
  final String description;
  final String location;
  final Repeat? repeat;

  /// When its alerts come, before the time they count from (an event's
  /// start, a task's due time).
  final List<Duration> alerts;

  /// Its own color; `null` for none (it shows in its calendar's).
  final EventColor? color;

  /// The time its repeat counts from (see [ItemPart.anchor]); `null` if
  /// it has none.
  CalendarTime? get anchor;

  /// The times it writes, for the time zones they are in.
  List<CalendarTime> get times;

  /// The key of an item [uid] of its kind.
  UidKey keyOf(String uid);

  /// This draft for one date, [anchor] instead of its own, its other
  /// times moved along on its clock; it doesn't repeat.
  ItemDraft dateAt(CalendarTime anchor);

  /// This draft as it is, but not repeating.
  ItemDraft get single;

  /// What is to be written when a form started from [from] ends as this
  /// draft, while the item became [now] meanwhile (e.g. changed on another
  /// device): what the user changed as this draft says, the rest as [now]
  /// says. Its times count as one. This draft if the three aren't of one
  /// kind.
  ItemDraft over(ItemDraft from, ItemDraft now) => switch ((this, from, now)) {
    (final EventDraft draft, final EventDraft from, final EventDraft now) =>
      draft._over(from, now),
    (final TaskDraft draft, final TaskDraft from, final TaskDraft now) =>
      draft._over(from, now),
    _ => this,
  };

  /// Whether [alerts] are those of [part].
  bool sameAlertsAs(ItemPart part) =>
      const ListEquality<Duration>().equals(alerts, part.alerts);

  /// The alerts the user wants, as [_pick] picks a field.
  List<Duration> _alertsOver(ItemDraft from, ItemDraft now) =>
      const ListEquality<Duration>().equals(alerts, from.alerts)
      ? now.alerts
      : alerts;

  bool _sameShared(ItemDraft other) =>
      other.summary == summary &&
      other.description == description &&
      other.location == location &&
      other.repeat == repeat &&
      const ListEquality<Duration>().equals(other.alerts, alerts) &&
      other.color == color;

  int get _sharedHash => Object.hash(
    summary,
    description,
    location,
    repeat,
    const ListEquality<Duration>().hash(alerts),
    color,
  );
}

/// What an event is to be, as the event or health form states it.
final class EventDraft extends ItemDraft {
  const EventDraft({
    required super.summary,
    required this.start,
    required this.end,
    super.description,
    super.location,
    super.repeat,
    super.alerts,
    this.health,
    super.color,
  });

  /// A health [entry] on [day], with an optional [note].
  EventDraft.health(HealthEntry entry, DateTime day, {String note = ''})
    : this(
        summary: entry.summary,
        start: AllDay(day),
        end: AllDay(day.add(const Duration(days: 1))),
        description: note,
        health: entry,
      );

  /// What [part] says now, to start a form from.
  EventDraft.of(EventPart part)
    : this(
        summary: part.summary,
        start: part.start!,
        end: part.end!,
        description: part.description,
        location: part.location,
        repeat: part.repeat,
        alerts: part.alerts,
        health: part.health,
        color: part.color,
      );

  final CalendarTime start;

  /// When it ends; for a day, the day after its last.
  final CalendarTime end;
  final HealthEntry? health;

  @override
  CalendarTime get anchor => start;

  @override
  List<CalendarTime> get times => [start, end];

  @override
  UidKey keyOf(String uid) => UidKey.event(uid);

  @override
  EventDraft dateAt(CalendarTime anchor) =>
      occurrenceAt(anchor, anchor.at(anchor.wall.add(lengthOn(start, end))));

  @override
  EventDraft get single => occurrenceAt(start, end);

  /// This draft for one occurrence, from [start] to [end]: it doesn't
  /// repeat.
  EventDraft occurrenceAt(CalendarTime start, CalendarTime end) => EventDraft(
    summary: summary,
    start: start,
    end: end,
    description: description,
    location: location,
    alerts: alerts,
    health: health,
    color: color,
  );

  EventDraft _over(EventDraft from, EventDraft now) {
    final timesChanged = start != from.start || end != from.end;
    return EventDraft(
      summary: _pick(summary, from.summary, now.summary),
      start: timesChanged ? start : now.start,
      end: timesChanged ? end : now.end,
      description: _pick(description, from.description, now.description),
      location: _pick(location, from.location, now.location),
      repeat: _pick(repeat, from.repeat, now.repeat),
      alerts: _alertsOver(from, now),
      health: _pick(health, from.health, now.health),
      color: _pick(color, from.color, now.color),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventDraft &&
      _sameShared(other) &&
      other.start == start &&
      other.end == end &&
      other.health == health;

  @override
  int get hashCode => Object.hash(_sharedHash, start, end, health);
}

/// What a task is to be, as the task form states it: due on a day or at
/// a time, or never ([due] `null`).
final class TaskDraft extends ItemDraft {
  const TaskDraft({
    required super.summary,
    this.due,
    this.start,
    super.description,
    super.location,
    super.repeat,
    super.alerts,
    super.color,
  });

  /// What [part] says now, to start a form from.
  TaskDraft.of(TaskPart part)
    : this(
        summary: part.summary,
        due: part.due,
        start: part.start,
        description: part.description,
        location: part.location,
        repeat: part.repeat,
        alerts: part.alerts,
        color: part.color,
      );

  /// When it is due; `null` for never.
  final CalendarTime? due;

  /// When it starts, if it says (other apps write it; the form shows
  /// only [due], and [withDue] moves it along).
  final CalendarTime? start;

  @override
  CalendarTime? get anchor => start ?? due;

  @override
  List<CalendarTime> get times => [?start, ?due];

  @override
  UidKey keyOf(String uid) => UidKey.task(uid);

  /// This draft due [due] instead: its start moved along by as much, on
  /// the due time's clock, while both are of one kind (a day, or a time
  /// of day); else it has no start, so it has no dates its form doesn't
  /// show. Without a due time it doesn't repeat.
  TaskDraft withDue(CalendarTime? due) {
    final (was, start) = (this.due, this.start);
    return TaskDraft(
      summary: summary,
      due: due,
      start: switch ((was, start, due)) {
        (final was?, final start?, final due?)
            when (was is AllDay) == (due is AllDay) &&
                (start is AllDay) == (due is AllDay) =>
          start.at(start.wall.add(due.wall.difference(was.wall))),
        _ => null,
      },
      description: description,
      location: location,
      repeat: due == null ? null : repeat,
      alerts: alerts,
      color: color,
    );
  }

  @override
  TaskDraft dateAt(CalendarTime anchor) {
    final (start, due) = (this.start, this.due);
    return TaskDraft(
      summary: summary,
      due: switch ((start, due)) {
        (final start?, final due?) => anchor.at(
          anchor.wall.add(offsetOn(start, due)),
        ),
        (null, _?) => anchor,
        (_, null) => null,
      },
      start: start == null ? null : anchor,
      description: description,
      location: location,
      alerts: alerts,
      color: color,
    );
  }

  @override
  TaskDraft get single => TaskDraft(
    summary: summary,
    due: due,
    start: start,
    description: description,
    location: location,
    alerts: alerts,
    color: color,
  );

  TaskDraft _over(TaskDraft from, TaskDraft now) {
    final timesChanged = due != from.due || start != from.start;
    return TaskDraft(
      summary: _pick(summary, from.summary, now.summary),
      due: timesChanged ? due : now.due,
      start: timesChanged ? start : now.start,
      description: _pick(description, from.description, now.description),
      location: _pick(location, from.location, now.location),
      repeat: _pick(repeat, from.repeat, now.repeat),
      alerts: _alertsOver(from, now),
      color: _pick(color, from.color, now.color),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskDraft &&
      _sameShared(other) &&
      other.due == due &&
      other.start == start;

  @override
  int get hashCode => Object.hash(_sharedHash, due, start);
}

/// [mine], what the user's form says, if they changed it from [from];
/// else [now], as the item says now.
T _pick<T>(T mine, T from, T now) => mine != from ? mine : now;
