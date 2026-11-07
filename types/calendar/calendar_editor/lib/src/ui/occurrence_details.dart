import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_dot.dart';
import 'event_colors.dart';
import 'occurrence_texts.dart';

/// What [occurrence] is, in full: its whole title (after a dot of its
/// own color, if it has one), its day and times
/// (also on its own clock, where that is another zone's), its place and
/// its notes.
class OccurrenceDetails extends StatelessWidget {
  const OccurrenceDetails(this.occurrence, {super.key});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final part = occurrence.part;
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final times = timesOf(words, occurrence, use24Hour: use24Hour);
    return ListTile(
      titleAlignment: ListTileTitleAlignment.top,
      leading: switch (ownColor(occurrence)) {
        final color? => CalendarDot(color),
        null => null,
      },
      title: Text(occurrenceTitle(occurrence)),
      subtitle: Text(
        [
          '${words.formatFullDate(occurrence.start)} · $times',
          ?ownTimesOf(words, occurrence, use24Hour: use24Hour),
          if (part.location.isNotEmpty) part.location,
          if (part.description.isNotEmpty) part.description,
        ].join('\n'),
      ),
    );
  }
}
