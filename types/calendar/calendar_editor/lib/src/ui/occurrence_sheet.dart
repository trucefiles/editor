import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'occurrence_details.dart';

/// One thing to do with an occurrence, as its sheet lists it: [value]
/// stands for it.
typedef OccurrenceAction<T> = ({IconData icon, String label, T value});

/// Shows [occurrence] in full in a sheet, its text selectable, with
/// [actions] below it; first the [calendar] it is in, if given (where
/// several calendars show together). The value of the action the user
/// picks, `null` if they close the sheet.
Future<T?> showOccurrenceSheet<T>(
  BuildContext context,
  Occurrence occurrence,
  List<OccurrenceAction<T>> actions, {
  SheetCalendar? calendar,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // The actions stay plain taps, outside the selectable text.
        SelectionArea(
          child: Padding(
            // As a list row's, so the details line up with the actions.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OccurrenceDetails(occurrence, calendar: calendar),
          ),
        ),
        if (actions.isNotEmpty) const Divider(),
        for (final (:icon, :label, :value) in actions)
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.pop(context, value),
          ),
      ],
    ),
  ),
);
