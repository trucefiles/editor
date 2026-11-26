import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../ui/event_colors.dart';
import '../ui/occurrence_texts.dart';
import 'occurrence_event.dart';
import 'task_box.dart';

/// How occurrences look in the month, week and day views: a tile in
/// their color ([shownColor], over their calendar's: [colorOf] its
/// key) with their title in up to [lines] lines (one line is cut
/// anywhere, with "…"), a task's after its box (a tap on it tells
/// [onCheck]; without it the box only shows), a done one's struck
/// through; while dragged, the same tile where it would land; a range
/// dragged over for a new event, marked.
TileComponents eventTiles<K>(
  Color Function(K calendar) colorOf, {
  required int lines,
  OnCheck<K>? Function()? onCheck,
}) {
  Widget tile(KalenderEvent event, {Size? size, double opacity = 1}) => Opacity(
    opacity: opacity,
    child: SizedBox.fromSize(
      size: size,
      child: switch (event) {
        OccurrenceEvent<K>(:final calendar, :final occurrence) => _Tile(
          shownColor(occurrence.part, colorOf(calendar)),
          occurrence,
          lines: lines,
          onCheck: switch ((occurrence, onCheck?.call())) {
            (final TaskOccurrence task, final onCheck?) => (done) => onCheck(
              calendar,
              TaskEntry.of(task),
              done,
            ),
            _ => null,
          },
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

/// How occurrences look in the schedule view: a dot in their color (a
/// task: its box, as [eventTiles] has it), their title and their times
/// (a task's: when it is due).
ScheduleTileComponents scheduleTiles<K>(
  Color Function(K calendar) colorOf, {
  OnCheck<K>? Function()? onCheck,
}) => ScheduleTileComponents(
  tileBuilder: (context, event, _) {
    final shown = event as OccurrenceEvent<K>;
    final occurrence = shown.occurrence;
    final color = shownColor(occurrence.part, colorOf(shown.calendar));
    final words = MaterialLocalizations.of(context);
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final check = onCheck?.call();
    return ListTile(
      dense: true,
      leading: switch (occurrence) {
        final TaskOccurrence task => TaskBox(
          done: task.done,
          color: color,
          onChanged: check == null
              ? null
              : (done) => check(shown.calendar, TaskEntry.of(task), done),
        ),
        EventOccurrence() => Icon(Icons.circle, size: 14, color: color),
      },
      title: Text(itemTitle(occurrence.part), style: _doneStyle(occurrence)),
      subtitle: Text(
        [
          switch (occurrence) {
            final TaskOccurrence task => dueTimeText(
              words,
              TaskEntry.of(task),
              use24Hour: use24Hour,
            ),
            EventOccurrence() => timesOf(
              words,
              occurrence,
              use24Hour: use24Hour,
            ),
          },
          if (occurrence.part.location.isNotEmpty) occurrence.part.location,
        ].join(' · '),
      ),
    );
  },
);

/// How a done task's title looks: struck through; `null` for the rest.
TextStyle? _doneStyle(Occurrence occurrence) => switch (occurrence) {
  TaskOccurrence(done: true) => const TextStyle(
    decoration: TextDecoration.lineThrough,
  ),
  _ => null,
};

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

/// One occurrence's tile: its title on its calendar's [color], in up to
/// [lines] lines; a task's after its box, which tells [onCheck].
class _Tile extends StatelessWidget {
  const _Tile(this.color, this.occurrence, {required this.lines, this.onCheck});

  final Color color;
  final Occurrence occurrence;
  final int lines;
  final ValueChanged<bool>? onCheck;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      margin: _tileMargin,
      padding: _tilePadding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: switch (occurrence) {
        final TaskOccurrence task => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskBox(
              done: task.done,
              color: onColor,
              size: 14,
              onChanged: onCheck,
            ),
            const SizedBox(width: 2),
            Expanded(child: _title(context, onColor)),
          ],
        ),
        EventOccurrence() => _title(context, onColor),
      },
    );
  }

  Widget _title(BuildContext context, Color onColor) => Text(
    itemTitle(occurrence.part),
    maxLines: lines,
    // One line keeps as much of the title as fits, not whole words.
    softWrap: lines > 1,
    overflow: TextOverflow.ellipsis,
    style: _titleStyle(context)
        ?.copyWith(color: onColor)
        .merge(_doneStyle(occurrence)),
  );
}

const _tileMargin = EdgeInsets.all(1);
const _tilePadding = EdgeInsets.symmetric(horizontal: 4, vertical: 1);

/// How a tile's title is written, before its color.
TextStyle? _titleStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelMedium;

/// The least height of a tile of [eventTiles]: one line of its title at
/// the user's text size, so a short event's title still shows.
double oneLineTileHeight(BuildContext context) {
  final line = TextPainter(
    text: TextSpan(text: ' ', style: _titleStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = line.height;
  line.dispose();
  return height + _tileMargin.vertical + _tilePadding.vertical;
}
