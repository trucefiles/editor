import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../views/new_event_spot.dart';
import 'event_form.dart';
import 'occurrence_details.dart';

/// Makes a calendar edit at the time it is given.
typedef MakeEdit = void Function(CalendarEdit Function(DateTime at) edit);

/// Asks for a new event at [spot] and adds it: at its times, over its
/// whole days, else on its day from 9:00 for an hour; times in the
/// device's zone.
Future<void> addEvent(
  BuildContext context,
  NewEventSpot spot,
  MakeEdit edit,
  DeviceZone deviceZone,
) async {
  final zone = await deviceZone();
  if (!context.mounted) return;
  CalendarTime at(DateTime time, {int? hour}) => timeAt(
    DateTime.utc(
      time.year,
      time.month,
      time.day,
      hour ?? time.hour,
      hour == null ? time.minute : 0,
    ),
    allDay: false,
    deviceZone: zone,
  );
  final (start, end) = switch (spot) {
    AtTimes(:final start, :final end) => (at(start), at(end)),
    OnDays(:final first, :final end) => (AllDay(first), AllDay(end)),
    OnDay(:final day) => (at(day, hour: 9), at(day, hour: 10)),
  };
  final draft = await showEventForm(
    context,
    EventDraft(summary: '', start: start, end: end),
    title: 'New event',
    deviceZone: zone,
  );
  if (draft == null) return;
  final uid = newUid();
  edit((at) => AddEvent(uid, draft, at: at));
}

/// Shows [occurrence] in full and, if [edit] is given, what the user can
/// do with it: edit or delete it, and for one of a series, just this one
/// or the whole series.
Future<void> showOccurrence(
  BuildContext context,
  Occurrence occurrence,
  MakeEdit? edit,
  DeviceZone deviceZone,
) async {
  final one = occurrence.recurrence;
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          OccurrenceDetails(occurrence),
          if (edit != null) ...[
            const Divider(),
            for (final action
                in one == null ? _Action.single : _Action.ofSeries)
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ],
      ),
    ),
  );
  if (action == null || edit == null || !context.mounted) return;
  await _act(context, occurrence, action, edit, deviceZone);
}

/// Does [action] on [occurrence].
Future<void> _act(
  BuildContext context,
  Occurrence occurrence,
  _Action action,
  MakeEdit edit,
  DeviceZone deviceZone,
) async {
  final uid = occurrence.event.uid;
  final one = occurrence.recurrence;
  final zone = switch (action) {
    _Action.edit || _Action.editAll || _Action.editOne => await deviceZone(),
    _ => null,
  };
  if (!context.mounted) return;
  switch (action) {
    case _Action.edit || _Action.editAll:
      final from = EventDraft.of(occurrence.event.series);
      final draft = await showEventForm(
        context,
        from,
        title: 'Edit event',
        deviceZone: zone,
      );
      if (draft != null) {
        edit((at) => ChangeSeries(uid, draft, from: from, at: at));
      }
    case _Action.editOne:
      final from = occurrenceDraft(occurrence);
      final draft = await showEventForm(
        context,
        from,
        title: 'Edit this one',
        deviceZone: zone,
        repeats: false,
      );
      if (draft != null && one != null) {
        edit((at) => ChangeOccurrence(uid, one, draft, from: from, at: at));
      }
    case _Action.deleteOne:
      if (one != null) edit((at) => DeleteOccurrence(uid, one, at: at));
    case _Action.delete || _Action.deleteAll:
      edit((at) => DeleteEvent(uid, at: at));
  }
}

enum _Action {
  edit('Edit', Icons.edit_outlined),
  delete('Delete', Icons.delete_outline),
  editOne('Edit this one', Icons.edit_outlined),
  editAll('Edit all of them', Icons.edit_calendar_outlined),
  deleteOne('Delete this one', Icons.delete_outline),
  deleteAll('Delete all of them', Icons.delete_sweep_outlined);

  const _Action(this.label, this.icon);

  final String label;
  final IconData icon;

  static const single = [edit, delete];
  static const ofSeries = [editOne, editAll, deleteOne, deleteAll];
}
