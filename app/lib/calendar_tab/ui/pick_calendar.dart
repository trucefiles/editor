import 'package:flutter/material.dart';
import 'package:truce_files/truce_files.dart';

import '../calendar_tab_controller.dart';
import 'calendar_dot.dart';

/// The calendar of [calendars] to open: the only one, else the one the
/// user picks, each shown by its color ([colorOf]) and title; `null` if
/// there is none or the user cancels.
Future<ListedFile?> pickCalendar(
  BuildContext context,
  List<TabCalendar> calendars,
  Color Function(ListedFile file) colorOf,
) async => switch (calendars) {
  [] => null,
  [final only] => only.file,
  _ => await showDialog<ListedFile>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Open which calendar?'),
      children: [
        for (final calendar in calendars)
          SimpleDialogOption(
            // As tall as a touch target, so each is easy to hit.
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () => Navigator.pop(context, calendar.file),
            child: Row(
              spacing: 16,
              children: [
                CalendarDot(colorOf(calendar.file)),
                Flexible(child: Text(calendar.title)),
              ],
            ),
          ),
      ],
    ),
  ),
};
