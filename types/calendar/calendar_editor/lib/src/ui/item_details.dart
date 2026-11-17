import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_dot.dart';
import 'event_colors.dart';
import 'event_links.dart';
import 'marked_line.dart';
import 'occurrence_texts.dart';
import 'openable_line.dart';
import 'selectable_lines.dart';

/// The calendar an occurrence is in, as a sheet names it: its [color]
/// and [title].
typedef SheetCalendar = ({Color color, String title});

/// One line of what an item says, after an [icon] that says what it is.
typedef DetailLine = ({IconData icon, String text});

/// What an event's or task's [part] is, in full, one part per line, 8
/// apart (and so copied): first the [calendar] it is in, if given (where
/// several calendars show together), quieter; then its whole title
/// (after a dot of its own color, if it has one); then [when] it is
/// (its kind's lines); then its place and its notes, each after an icon
/// that says what it is. With [links], the links in its place and notes
/// open, and a place that holds none opens in a maps app.
class ItemDetails extends StatelessWidget {
  const ItemDetails(
    this.part, {
    required this.when,
    this.calendar,
    this.links,
    super.key,
  });

  final ItemPart part;
  final List<DetailLine> when;
  final SheetCalendar? calendar;
  final EventLinks? links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final partStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    Widget partMark(IconData icon) => Icon(icon, size: 20, color: muted);
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
            text: itemTitle(part),
            style: theme.textTheme.titleMedium,
          ),
          for (final (:icon, :text) in when)
            MarkedLine(mark: partMark(icon), text: text, style: partStyle),
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

/// What the event [occurrence] is, in full ([ItemDetails]): when, its day
/// and times (also on its own clock, where that is another zone's).
class OccurrenceDetails extends StatelessWidget {
  const OccurrenceDetails(
    this.occurrence, {
    this.calendar,
    this.links,
    super.key,
  });

  final EventOccurrence occurrence;
  final SheetCalendar? calendar;
  final EventLinks? links;

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final times = timesOf(words, occurrence, use24Hour: use24Hour);
    return ItemDetails(
      occurrence.part,
      calendar: calendar,
      links: links,
      when: [
        (
          icon: Icons.schedule,
          text: [
            '${words.formatFullDate(occurrence.start)} · $times',
            ?ownTimesOf(words, occurrence, use24Hour: use24Hour),
          ].join('\n'),
        ),
      ],
    );
  }
}

/// What the task [entry] is, in full ([ItemDetails]): when, when it is
/// due, and that it is done.
class TaskDetails extends StatelessWidget {
  const TaskDetails(this.entry, {this.calendar, this.links, super.key});

  final TaskEntry entry;
  final SheetCalendar? calendar;
  final EventLinks? links;

  @override
  Widget build(BuildContext context) => ItemDetails(
    entry.part,
    calendar: calendar,
    links: links,
    when: [
      (
        icon: Icons.event_available_outlined,
        text: dueText(
          MaterialLocalizations.of(context),
          entry,
          use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
        ),
      ),
      if (entry.done) (icon: Icons.task_alt, text: 'Done'),
    ],
  );
}
