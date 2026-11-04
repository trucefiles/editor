import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'event_actions.dart';
import 'health_entry_form.dart';
import 'occurrence_sheet.dart';

/// Asks which kind of health entry to add on [day], then for the entry,
/// and adds it.
Future<void> addHealthEntry(
  BuildContext context,
  DateTime day,
  MakeEdit edit,
) async {
  final entry = await showModalBottomSheet<HealthEntry>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final (label, entry) in healthKinds)
            ListTile(
              title: Text(label),
              onTap: () => Navigator.pop(context, entry),
            ),
        ],
      ),
    ),
  );
  if (entry == null || !context.mounted) return;
  final made = await showHealthEntryForm(context, entry, title: 'New entry');
  if (made == null) return;
  final uid = newUid();
  final key = DateTime.utc(day.year, day.month, day.day);
  edit(
    (at) => AddEvent(
      uid,
      EventDraft.health(made.entry, key, note: made.note),
      at: at,
    ),
  );
}

/// Shows the health entry [occurrence] in full and, if [edit] is given,
/// offers to edit it in its own form or to delete it.
Future<void> showHealthEntry(
  BuildContext context,
  Occurrence occurrence,
  MakeEdit? edit,
) async {
  final delete = await showOccurrenceSheet(context, occurrence, [
    if (edit != null) ...[
      (icon: Icons.edit_outlined, label: 'Edit', value: false),
      (icon: Icons.delete_outline, label: 'Delete', value: true),
    ],
  ]);
  if (delete == null || edit == null || !context.mounted) return;
  if (delete) {
    return edit((at) => DeleteEvent(occurrence.event.uid, at: at));
  }
  await editHealthEntry(context, occurrence, edit);
}

/// Opens the health entry [occurrence] in its own form and saves what the
/// user changes; it keeps its day.
Future<void> editHealthEntry(
  BuildContext context,
  Occurrence occurrence,
  MakeEdit edit,
) async {
  final event = occurrence.event;
  final part = event.series;
  final made = await showHealthEntryForm(
    context,
    part.health!,
    note: part.description,
    title: 'Edit entry',
  );
  if (made == null) return;
  final day = part.start!.wall;
  edit(
    (at) => ChangeSeries(
      event.uid,
      EventDraft.health(made.entry, day, note: made.note),
      from: EventDraft.health(part.health!, day, note: part.description),
      at: at,
    ),
  );
}
