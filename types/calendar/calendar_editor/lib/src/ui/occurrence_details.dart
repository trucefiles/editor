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
    final title = occurrenceTitle(occurrence);
    return ListTile(
      title: switch (ownColor(occurrence)) {
        // In the title's first line, so the dot is centered on it.
        final color? => Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: CalendarDot(color),
                ),
              ),
              TextSpan(text: title),
            ],
          ),
        ),
        null => Text(title),
      },
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
