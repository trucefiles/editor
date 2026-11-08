import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_dot.dart';
import 'event_colors.dart';
import 'marked_line.dart';
import 'occurrence_texts.dart';

/// What [occurrence] is, in full, one part per line: its whole title
/// (after a dot of its own color, if it has one), its day and times
/// (also on its own clock, where that is another zone's), its place and
/// its notes, each after an icon that says what it is.
class OccurrenceDetails extends StatelessWidget {
  const OccurrenceDetails(this.occurrence, {super.key});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final partStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final words = MaterialLocalizations.of(context);
    final part = occurrence.part;
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final times = timesOf(words, occurrence, use24Hour: use24Hour);
    MarkedLine partLine(IconData icon, String text) => MarkedLine(
      mark: Icon(icon, size: 20, color: muted),
      text: text,
      style: partStyle,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
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
          partLine(Icons.place_outlined, part.location),
        if (part.description.isNotEmpty)
          partLine(Icons.notes, part.description),
      ],
    );
  }
}
