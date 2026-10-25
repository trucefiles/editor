import 'line.dart';

/// A line a change puts in: one that keeps an existing [id], or a new one
/// (`id` `null`) that gets a fresh id.
typedef NewLine = ({LineId? id, String text});

/// A change to a document's lines: the lines from [start] to [end] (indexes
/// before the change) replaced by [lines].
final class LineChange {
  LineChange(this.start, this.end, List<NewLine> lines)
    : lines = List.unmodifiable(lines),
      assert(start <= end, 'a change ends after it starts');

  final int start;
  final int end;
  final List<NewLine> lines;

  @override
  String toString() => 'LineChange($start, $end, $lines)';
}
