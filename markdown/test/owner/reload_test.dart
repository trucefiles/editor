import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/owner/reload.dart';
import 'package:truce_markdown/src/view/rows.dart';

/// The row the caret in row [row] of [before] goes to in [after].
int _mappedRow(String before, String after, int row) {
  final old = loaded(before);
  final oldView = ViewRows(old.doc);
  final next = loaded(after);
  final view = ViewRows(next.doc);
  final mapped = mappedSelection(
    TextSelection.caret(Place(oldView.rows[row].leaf.id, 0)),
    old.printed,
    next,
    view,
  );
  return view.rowOf((mapped as TextSelection).extent.leaf)!;
}

void main() {
  // Over 500 lines in all, diffutil finds matches another way.
  for (final count in [20, 600]) {
    test('a caret follows its line through changes elsewhere ($count)', () {
      final lines = [for (var line = 0; line < count; line++) 'line $line'];
      final changed = [
        'added at the start',
        for (final (index, line) in lines.indexed)
          if (index % 7 != 3) index % 5 == 0 ? 'changed $index' : line,
      ];
      final before = lines.join('\n\n');
      final after = changed.join('\n\n');
      for (final row in [1, count ~/ 2 + 1, count - 2]) {
        final kept = lines[row];
        expect(
          changed[_mappedRow(before, after, row)],
          row % 7 == 3 || row % 5 == 0 ? isNot(kept) : kept,
          reason: 'row $row',
        );
      }
    });
  }
}
