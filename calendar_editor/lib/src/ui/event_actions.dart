import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'event_form.dart';

/// Makes a calendar edit at the time it is given.
typedef MakeEdit = void Function(CalendarEdit Function(DateTime at) edit);

/// Asks for a new event on [day] and adds it.
Future<void> addEvent(BuildContext context, DateTime day, MakeEdit edit) async {
  final draft = await showEventForm(
    context,
    EventDraft(
      summary: '',
      start: Floating(DateTime(day.year, day.month, day.day, 9)),
      end: Floating(DateTime(day.year, day.month, day.day, 10)),
    ),
    title: 'New event',
  );
  if (draft == null) return;
  final uid = newUid();
  edit((at) => AddEvent(uid, draft, at: at));
}

/// What the user can do with [occurrence]: edit or delete it, and for one
/// of a series, just this one or the whole series.
Future<void> showOccurrenceActions(
  BuildContext context,
  Occurrence occurrence,
  MakeEdit edit,
) async {
  final uid = occurrence.event.uid;
  final one = occurrence.recurrence;
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final action in one == null ? _Action.single : _Action.ofSeries)
            ListTile(
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () => Navigator.pop(context, action),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _Action.edit || _Action.editAll:
      final draft = await showEventForm(
        context,
        EventDraft.of(occurrence.event.series),
        title: 'Edit event',
      );
      if (draft != null) edit((at) => ChangeSeries(uid, draft, at: at));
    case _Action.editOne:
      final draft = await showEventForm(
        context,
        _occurrenceDraft(occurrence),
        title: 'Edit this one',
      );
      if (draft != null && one != null) {
        edit((at) => ChangeOccurrence(uid, one, draft, at: at));
      }
    case _Action.deleteOne:
      if (one != null) edit((at) => DeleteOccurrence(uid, one, at: at));
    case _Action.delete || _Action.deleteAll:
      edit((at) => DeleteEvent(uid, at: at));
  }
}

/// What the form starts with for [occurrence] alone: a changed one as it
/// is, else the series at the occurrence's time.
EventDraft _occurrenceDraft(Occurrence occurrence) {
  final part = occurrence.part;
  final draft = EventDraft.of(part);
  final one = occurrence.recurrence;
  if (part.recurrenceId != null || one == null) return draft;
  final length = draft.end.wall.difference(draft.start.wall);
  return draft.occurrenceAt(one, one.at(one.wall.add(length)));
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
