import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../views/new_event_spot.dart';
import 'event_form.dart';
import 'occurrence_sheet.dart';
import 'task_form.dart';

/// Makes a calendar edit at the time it is given.
typedef MakeEdit = void Function(CalendarEdit Function(DateTime at) edit);

/// Asks for a new event at [spot] and adds it: at its times, else over
/// its whole days (a tapped day: that day); times in the device's zone.
Future<void> addEvent(
  BuildContext context,
  NewEventSpot spot,
  MakeEdit edit,
  DeviceZone deviceZone,
) async {
  final zone = await deviceZone();
  if (!context.mounted) return;
  final (start, end) = switch (spot) {
    AtTimes(:final start, :final end) => (
      _timeAt(start, zone),
      _timeAt(end, zone),
    ),
    OnDays(:final first, :final end) => (AllDay(first), AllDay(end)),
    OnDay(:final day) => (
      AllDay(day),
      AllDay(DateTime(day.year, day.month, day.day + 1)),
    ),
  };
  final draft = await showEventForm(
    context,
    EventDraft(summary: '', start: start, end: end),
    title: 'New event',
    deviceZone: zone,
  );
  if (draft == null) return;
  final uid = newUid();
  edit((at) => AddItem(uid, draft, at: at));
}

/// Asks for a new task and adds it: due where [spot] starts (a day: all
/// that day), or with no due date; a time in the device's zone. A due
/// date turned on in the form starts on [today].
Future<void> addTask(
  BuildContext context,
  NewEventSpot? spot,
  MakeEdit edit,
  DeviceZone deviceZone, {
  required DateTime today,
}) async {
  final zone = await deviceZone();
  if (!context.mounted) return;
  final draft = await showTaskForm(
    context,
    TaskDraft(
      summary: '',
      due: switch (spot) {
        AtTimes(:final start) => _timeAt(start, zone),
        final OnDays spot => AllDay(spot.first),
        final OnDay spot => AllDay(spot.day),
        null => null,
      },
    ),
    title: 'New task',
    deviceZone: zone,
    today: today,
  );
  if (draft == null) return;
  final uid = newUid();
  edit((at) => AddItem(uid, draft, at: at));
}

/// The time of day [time] (on this device's clock) for a new item, in
/// [zone], the device's.
CalendarTime _timeAt(DateTime time, String? zone) => timeAt(
  DateTime.utc(time.year, time.month, time.day, time.hour, time.minute),
  allDay: false,
  deviceZone: zone,
);

/// Shows the event [occurrence] in full and, if [edit] is given, what the
/// user can do with it: edit or delete it, and for one of a series, just
/// this one or the whole series.
Future<void> showOccurrence(
  BuildContext context,
  EventOccurrence occurrence,
  MakeEdit? edit,
  DeviceZone deviceZone, {
  required DateTime today,
}) async {
  final action = await showOccurrenceSheet(
    context,
    occurrence,
    _actionsFor(occurrence.recurrence, editable: edit != null),
  );
  if (action == null || edit == null || !context.mounted) return;
  await _act(
    context,
    _eventTarget(occurrence),
    action,
    edit,
    deviceZone,
    today: today,
  );
}

/// Shows the task [entry] in full and what the user can do with it, as
/// [showOccurrence] does for an event.
Future<void> showTask(
  BuildContext context,
  TaskEntry entry,
  MakeEdit? edit,
  DeviceZone deviceZone, {
  required DateTime today,
}) async {
  final check = entry.done ? _Action.uncheck : _Action.check;
  final action = await showTaskSheet(context, entry, [
    if (edit != null) (icon: check.icon, label: check.label, value: check),
    ..._actionsFor(entry.date, editable: edit != null),
  ]);
  if (action == null || edit == null || !context.mounted) return;
  await _act(
    context,
    _taskTarget(entry),
    action,
    edit,
    deviceZone,
    today: today,
  );
}

/// Opens the form to edit the event [occurrence]: one that doesn't repeat
/// right away; one of a series shows its choices first (this one or all).
Future<void> editOccurrence(
  BuildContext context,
  EventOccurrence occurrence,
  MakeEdit edit,
  DeviceZone deviceZone, {
  required DateTime today,
}) => occurrence.recurrence == null
    ? _act(
        context,
        _eventTarget(occurrence),
        _Action.edit,
        edit,
        deviceZone,
        today: today,
      )
    : showOccurrence(context, occurrence, edit, deviceZone, today: today);

/// Opens the form to edit the task [entry], as [editOccurrence] does for
/// an event.
Future<void> editTask(
  BuildContext context,
  TaskEntry entry,
  MakeEdit edit,
  DeviceZone deviceZone, {
  required DateTime today,
}) => entry.date == null
    ? _act(
        context,
        _taskTarget(entry),
        _Action.edit,
        edit,
        deviceZone,
        today: today,
      )
    : showTask(context, entry, edit, deviceZone, today: today);

/// The actions on an item's date [date] (`null`: one that doesn't
/// repeat); none unless [editable].
List<OccurrenceAction<_Action>> _actionsFor(
  CalendarTime? date, {
  required bool editable,
}) => [
  if (editable)
    for (final action in date == null ? _Action.single : _Action.ofSeries)
      (icon: action.icon, label: action.label, value: action),
];

/// What the actions edit: the item [key], its date [date] (`null`: one
/// that doesn't repeat), and what its whole [series] and that [one] date
/// say now.
typedef _Target = ({
  UidKey key,
  CalendarTime? date,
  ItemDraft series,
  ItemDraft one,
});

/// What the actions on the event [occurrence] edit.
_Target _eventTarget(EventOccurrence occurrence) => (
  key: occurrence.item.key,
  date: occurrence.recurrence,
  series: ItemDraft.of(occurrence.item.series),
  one: occurrenceDraft(occurrence),
);

/// What the actions on the task [entry] edit.
_Target _taskTarget(TaskEntry entry) => (
  key: entry.task.key,
  date: entry.date,
  series: ItemDraft.of(entry.task.series),
  one: switch (entry.date) {
    final date? => ItemDraft.at(entry.task, date),
    null => ItemDraft.of(entry.part),
  },
);

/// Does [action] on [target]; a task form's due date turned on starts on
/// [today].
Future<void> _act(
  BuildContext context,
  _Target target,
  _Action action,
  MakeEdit edit,
  DeviceZone deviceZone, {
  required DateTime today,
}) async {
  final (:key, :date, :series, :one) = target;
  final uid = key.uid;
  final zone = switch (action) {
    _Action.edit || _Action.editAll || _Action.editOne => await deviceZone(),
    _ => null,
  };
  if (!context.mounted) return;
  Future<ItemDraft?> form(ItemDraft from, {required bool repeats}) =>
      switch (from) {
        EventDraft() => showEventForm(
          context,
          from,
          title: repeats ? 'Edit event' : 'Edit this one',
          deviceZone: zone,
          repeats: repeats,
        ),
        TaskDraft() => showTaskForm(
          context,
          from,
          title: repeats ? 'Edit task' : 'Edit this one',
          deviceZone: zone,
          today: today,
          repeats: repeats,
        ),
      };
  switch (action) {
    case _Action.edit || _Action.editAll:
      if (await form(series, repeats: true) case final draft?) {
        edit((at) => ChangeSeries(uid, draft, from: series, at: at));
      }
    case _Action.editOne:
      if ((await form(one, repeats: false), date) case (
        final draft?,
        final date?,
      )) {
        edit((at) => ChangeOccurrence(uid, date, draft, from: one, at: at));
      }
    case _Action.deleteOne:
      if (date != null) edit((at) => DeleteOccurrence(key, date, at: at));
    case _Action.delete || _Action.deleteAll:
      edit((at) => DeleteItem(key, at: at));
    case _Action.check || _Action.uncheck:
      final done = action == _Action.check;
      edit((at) => CheckTask(uid, date, done: done, at: at));
  }
}

enum _Action {
  edit('Edit', Icons.edit_outlined),
  delete('Delete', Icons.delete_outline),
  editOne('Edit this one', Icons.edit_outlined),
  editAll('Edit all of them', Icons.edit_calendar_outlined),
  deleteOne('Delete this one', Icons.delete_outline),
  deleteAll('Delete all of them', Icons.delete_sweep_outlined),
  check('Mark as done', Icons.task_alt),
  uncheck('Mark as not done', Icons.remove_done);

  const _Action(this.label, this.icon);

  final String label;
  final IconData icon;

  static const single = [edit, delete];
  static const ofSeries = [editOne, editAll, deleteOne, deleteAll];
}
