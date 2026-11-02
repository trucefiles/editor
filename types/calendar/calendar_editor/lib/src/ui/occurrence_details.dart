import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'occurrence_texts.dart';

/// What [occurrence] is, in full: its whole title, its day and times, its
/// place and its notes.
class OccurrenceDetails extends StatelessWidget {
  const OccurrenceDetails(this.occurrence, {super.key});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final part = occurrence.part;
    final times = timesOf(
      words,
      occurrence,
      use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return ListTile(
      title: Text(occurrenceTitle(occurrence)),
      subtitle: Text(
        [
          '${words.formatFullDate(occurrence.start)} · $times',
          if (part.location.isNotEmpty) part.location,
          if (part.description.isNotEmpty) part.description,
        ].join('\n'),
      ),
    );
  }
}
