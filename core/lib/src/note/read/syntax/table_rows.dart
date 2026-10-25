/// How GitHub Flavored Markdown splits table rows into cells. The one
/// owner of this rule.
library;

import '../../tree/blocks.dart';

/// One cell of a table row: its [text] without pipes and surrounding
/// spaces, from [start] to [end] in the row.
typedef RowCell = ({String text, int start, int end});

/// [row]'s cells: split at unescaped pipes, outer pipes dropped.
List<RowCell> splitTableRow(String row) {
  final cells = <RowCell>[];
  var start = 0;
  var end = row.length;
  final leading = row.length - row.trimLeft().length;
  final trailing = row.trimRight().length;
  if (leading < trailing && row[leading] == '|') start = leading + 1;
  if (trailing > start &&
      row[trailing - 1] == '|' &&
      (trailing < 2 || row[trailing - 2] != r'\')) {
    end = trailing - 1;
  }
  var cellStart = start;
  for (var index = start; index <= end; index++) {
    final atEnd = index == end;
    if (!atEnd && row[index] == r'\') {
      index++;
      continue;
    }
    if (atEnd || row[index] == '|') {
      final raw = row.substring(cellStart, index);
      final textStart = cellStart + raw.length - raw.trimLeft().length;
      final textEnd = cellStart + raw.trimRight().length;
      final cellEnd = textEnd < textStart ? textStart : textEnd;
      cells.add((
        text: row.substring(textStart, cellEnd),
        start: textStart,
        end: cellEnd,
      ));
      cellStart = index + 1;
    }
  }
  return cells;
}

/// The alignment a delimiter row's [cell] (`:--`, `:-:`, `--:`) gives.
CellAlignment alignmentOf(String cell) =>
    switch ((cell.startsWith(':'), cell.endsWith(':'))) {
      (true, true) => CellAlignment.center,
      (true, false) => CellAlignment.left,
      (false, true) => CellAlignment.right,
      (false, false) => CellAlignment.none,
    };
