import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'occurrence_details.dart';

/// One thing to do with an occurrence, as its sheet lists it: [value]
/// stands for it.
typedef OccurrenceAction<T> = ({IconData icon, String label, T value});

/// Shows [occurrence] in full in a sheet, with [actions] below it; the
/// value of the action the user picks, `null` if they close the sheet.
Future<T?> showOccurrenceSheet<T>(
  BuildContext context,
  Occurrence occurrence,
  List<OccurrenceAction<T>> actions,
) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        OccurrenceDetails(occurrence),
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
