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
  // diffutil's edit script runs from the end of [other] to its start, so
  // every position is one in [other]: one pass builds the lines from
  // the end, in reverse. Its docs only promise that the script applies
  // in order; this order is its code's, guarded by
  // `test/versions/diffutil_order_test.dart`.
  final reversed = <ComparedLine>[];
  // Removed lines of the change at hand: they go before its added lines.
  final removed = <ComparedLine>[];
  var end = other.length;

  /// Ends the change at hand; the lines of [other] from [start] to [end]
  /// are in both.
  void keepFrom(int start) {
    if (start >= end) return;
    reversed
      ..addAll(removed)
      ..addAll([
        for (final text in other.sublist(start, end).reversed)
          (text: text, origin: LineOrigin.both),
      ]);
    removed.clear();
    end = start;
  }

  final script = calculateListDiff(
    other,
    shown,
    detectMoves: false,
  ).getUpdatesWithData();
  for (final update in script) {
    switch (update) {
      case DataRemove(:final position, :final data):
        keepFrom(position + 1);
        removed.add((text: data, origin: LineOrigin.otherOnly));
        end = position;
      case DataInsert(:final position, :final data):
        keepFrom(position);
        reversed.add((text: data, origin: LineOrigin.shownOnly));
      case DataChange() || DataMove():
        throw StateError('A list diff without moves has no changes or moves');
    }
  }
  reversed.addAll(removed);
  removed.clear();
  keepFrom(0);
  return reversed.reversed.toList();
}
