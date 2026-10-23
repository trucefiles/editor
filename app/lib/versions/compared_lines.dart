import 'package:diffutil_dart/diffutil.dart';

/// Which of two compared versions has a line.
enum LineOrigin { both, shownOnly, otherOnly }

/// One line of two versions of a note, compared.
typedef ComparedLine = ({String text, LineOrigin origin});

/// The lines of [shown] and [other] in order, as a line diff from
/// [other] to [shown] shows them: lines both have, lines only [shown]
/// has, and lines only [other] has, where [shown] lacks them. Where one
/// changed into another, the [other] line comes first. A moved line is
/// removed in one place and added in the other.
List<ComparedLine> compareLines(List<String> shown, List<String> other) {
  final lines = <ComparedLine>[
    for (final text in other) (text: text, origin: LineOrigin.both),
  ];

  /// Where in [lines] the line at [position] of the text being edited
  /// from [other] into [shown] is, or its end.
  int at(int position) {
    final present = lines.indexed
        .where((entry) => entry.$2.origin != LineOrigin.otherOnly)
        .map((entry) => entry.$1)
        .skip(position);
    return present.isEmpty ? lines.length : present.first;
  }

  // An edit script from [other] to [shown], applied in order.
  for (final update in calculateListDiff(
    other,
    shown,
    detectMoves: false,
  ).getUpdatesWithData()) {
    switch (update) {
      case DataInsert(:final position, :final data):
        lines.insert(at(position), (text: data, origin: LineOrigin.shownOnly));
      case DataRemove(:final position, :final data):
        lines[at(position)] = (text: data, origin: LineOrigin.otherOnly);
      case DataChange() || DataMove():
        throw StateError('A list diff without moves has no changes or moves');
    }
  }
  return lines;
}
