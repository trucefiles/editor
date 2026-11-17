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

/// What [occurrence] is, in full, one part per line, 8 apart (and so
/// copied): first the
/// [calendar] it is in, if given (where several calendars show
/// together), quieter; then its whole title
/// (after a dot of its own color, if it has one), its day and times
/// (also on its own clock, where that is another zone's), its place and
/// its notes, each after an icon that says what it is. With [links],
/// the links in its place and notes open, and a place that holds none
/// opens in a maps app.
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final partStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final words = MaterialLocalizations.of(context);
    final part = occurrence.part;
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final times = timesOf(words, occurrence, use24Hour: use24Hour);
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
            mark: switch (ownColor(occurrence)) {
              final color? => CalendarDot(color),
              null => null,
            },
            text: occurrenceTitle(occurrence),
            style: theme.textTheme.titleMedium,
          ),
          partLine(
            Icons.schedule,
            [
              '${words.formatFullDate(occurrence.start)} · $times',
              ?ownTimesOf(words, occurrence, use24Hour: use24Hour),
            ].join('\n'),
          ),
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
