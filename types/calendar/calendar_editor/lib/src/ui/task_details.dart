import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_dot.dart';
import 'event_colors.dart';
import 'event_links.dart';
import 'marked_line.dart';
import 'occurrence_details.dart';
import 'occurrence_texts.dart';
import 'openable_line.dart';
import 'selectable_lines.dart';

/// What the task [entry] is, in full, one part per line, as
/// [OccurrenceDetails] shows an event: the [calendar] it is in, if given;
/// its whole title (after a dot of its own color, if it has one); when it
/// is due, and that it is done; its place and its notes, their links
/// opened by [links].
class TaskDetails extends StatelessWidget {
  const TaskDetails(this.entry, {this.calendar, this.links, super.key});

  final TaskEntry entry;
  final SheetCalendar? calendar;
  final EventLinks? links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final partStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final words = MaterialLocalizations.of(context);
    final part = entry.part;
    Widget partMark(IconData icon) => Icon(icon, size: 20, color: muted);
    MarkedLine partLine(IconData icon, String text) =>
        MarkedLine(mark: partMark(icon), text: text, style: partStyle);
    return SelectableLines(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (calendar case (:final color, :final title))
            MarkedLine(
              mark: CalendarDot(color),
              text: title,
              style: theme.textTheme.bodyMedium,
            ),
          MarkedLine(
            mark: switch (partColor(part)) {
              final color? => CalendarDot(color),
              null => null,
            },
            text: taskTitle(part),
            style: theme.textTheme.titleMedium,
          ),
          partLine(
            Icons.event_available_outlined,
            dueText(
              words,
              entry,
              use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
            ),
          ),
          if (entry.done) partLine(Icons.task_alt, 'Done'),
          if (part.location.isNotEmpty)
            OpenableLine(
              mark: partMark(Icons.place_outlined),
              text: part.location,
              style: partStyle,
              links: links,
              isPlace: true,
            ),
          if (part.description.isNotEmpty)
            OpenableLine(
              mark: partMark(Icons.notes),
              text: part.description,
              style: partStyle,
              links: links,
            ),
        ],
      ),
    );
  }
}
