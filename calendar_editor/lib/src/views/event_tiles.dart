import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../ui/occurrence_texts.dart';
import 'occurrence_event.dart';

/// How occurrences look in the month, week and day views: a tile in the
/// color of their calendar ([colorOf] its key) with their title; while
/// dragged, the same tile where it would land; a range dragged over for
/// a new event, marked.
TileComponents eventTiles<K>(Color Function(K calendar) colorOf) {
  Widget tile(KalenderEvent event, {Size? size, double opacity = 1}) => Opacity(
    opacity: opacity,
    child: SizedBox.fromSize(
      size: size,
      child: switch (event) {
        OccurrenceEvent<K>(:final calendar, :final occurrence) => _Tile(
          colorOf(calendar),
          occurrence,
        ),
        // The range a drag over free times marks for a new event.
        _ => const _NewTile(),
      },
    ),
  );

  return TileComponents(
    tileBuilder: (context, event, _) => tile(event),
    tileWhenDraggingBuilder: (context, event) => tile(event, opacity: 0.4),
    feedbackTileBuilder: (context, event, size) => Material(
      type: MaterialType.transparency,
      child: tile(event, size: size),
    ),
    dropTargetTile: (context, event) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

/// How occurrences look in the schedule view: a dot in their calendar's
/// color, their title and their times.
ScheduleTileComponents scheduleTiles<K>(Color Function(K calendar) colorOf) =>
    ScheduleTileComponents(
      tileBuilder: (context, event, _) {
        final shown = event as OccurrenceEvent<K>;
        final occurrence = shown.occurrence;
        return ListTile(
          dense: true,
          leading: Icon(Icons.circle, size: 14, color: colorOf(shown.calendar)),
          title: Text(occurrenceTitle(occurrence)),
          subtitle: Text(
            [
              timesOf(
                MaterialLocalizations.of(context),
                occurrence,
                use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
              ),
              if (occurrence.part.location.isNotEmpty) occurrence.part.location,
            ].join(' · '),
          ),
        );
      },
    );

/// The range marked for a new event, while the user drags over it.
class _NewTile extends StatelessWidget {
  const _NewTile();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      border: Border.all(color: Theme.of(context).colorScheme.primary),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

/// One occurrence's tile: its title on its calendar's [color].
class _Tile extends StatelessWidget {
  const _Tile(this.color, this.occurrence);

  final Color color;
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        occurrenceTitle(occurrence),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: onColor),
      ),
    );
  }
}
