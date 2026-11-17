import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'event_links.dart';
import 'occurrence_details.dart';
import 'task_details.dart';

/// One thing to do with an occurrence, as its sheet lists it: [value]
/// stands for it.
typedef OccurrenceAction<T> = ({IconData icon, String label, T value});

/// Shows the event [occurrence] in full in a sheet, its text selectable,
/// with [actions] below it; first the [calendar] it is in, if given
/// (where several calendars show together). The details show at the text
/// size of [context], where the sheet opens from (the views, at the
/// document text size), their links and place opened by its
/// [EventLinks]; the actions at the app's. The value of the action the
/// user picks, `null` if they close the sheet.
Future<T?> showOccurrenceSheet<T>(
  BuildContext context,
  EventOccurrence occurrence,
  List<OccurrenceAction<T>> actions, {
  SheetCalendar? calendar,
}) => _showSheet(
  context,
  (links) => OccurrenceDetails(occurrence, calendar: calendar, links: links),
  actions,
);

/// Shows the task [entry] in full in a sheet, as [showOccurrenceSheet]
/// shows an event.
Future<T?> showTaskSheet<T>(
  BuildContext context,
  TaskEntry entry,
  List<OccurrenceAction<T>> actions, {
  SheetCalendar? calendar,
}) => _showSheet(
  context,
  (links) => TaskDetails(entry, calendar: calendar, links: links),
  actions,
);

/// A sheet of [details] (their links opened by [EventLinks] of [context])
/// with [actions] below them, as [showOccurrenceSheet] tells.
Future<T?> _showSheet<T>(
  BuildContext context,
  Widget Function(EventLinks? links) details,
  List<OccurrenceAction<T>> actions,
) {
  final detailsScaler = MediaQuery.textScalerOf(context);
  final links = EventLinks.maybeOf(context);
  return showModalBottomSheet<T>(
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
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: detailsScaler),
                child: details(links),
              ),
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
}
