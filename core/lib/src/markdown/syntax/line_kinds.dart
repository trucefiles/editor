/// What a line is within its document, where its neighbors matter: code
/// blocks and tables span lines. One per line, in file order.
enum LineKind {
  /// Any line outside code blocks and tables.
  plain,

  /// A line that opens or closes a fenced code block (```` ``` ````).
  fence,

  /// A line inside a fenced code block.
  code,

  /// A line of a table: its header, delimiter row or a row.
  table,
}

/// The [LineKind] of each of [lines], in order.
List<LineKind> lineKinds(List<String> lines) {
  final kinds = List.filled(lines.length, LineKind.plain);
  String? fence;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final opening = _fence.firstMatch(line)?.group(1);
    if (fence != null) {
      final closes =
          opening != null &&
          opening[0] == fence[0] &&
          opening.length >= fence.length &&
          line.trim() == opening;
      kinds[i] = closes ? LineKind.fence : LineKind.code;
      if (closes) fence = null;
    } else if (opening != null) {
      kinds[i] = LineKind.fence;
      fence = opening;
    } else if (_startsTable(lines, i)) {
      var end = i + 2;
      while (end < lines.length && _isRow(lines[end])) {
        end++;
      }
      for (var j = i; j < end; j++) {
        kinds[j] = LineKind.table;
      }
      i = end - 1;
    }
  }
  return kinds;
}

/// Runs of [LineKind.table] lines in [kinds]: each table's first index and
/// the index past its last.
List<(int, int)> tableRanges(List<LineKind> kinds) => [
  for (var i = 0; i < kinds.length; i++)
    if (kinds[i] == LineKind.table &&
        (i == 0 || kinds[i - 1] != LineKind.table))
      (i, _runEnd(kinds, i)),
];

int _runEnd(List<LineKind> kinds, int start) {
  var end = start;
  while (end < kinds.length && kinds[end] == LineKind.table) {
    end++;
  }
  return end;
}

/// A table's cells: of its header and rows, without the delimiter row.
/// Cells are split at unescaped `|`, outer pipes dropped, trimmed.
List<List<String>> tableCells(List<String> table) => [
  for (final (index, row) in table.indexed)
    if (index != 1) _cells(row),
];

List<String> _cells(String row) {
  var text = row.trim();
  if (text.startsWith('|')) text = text.substring(1);
  if (text.endsWith('|') && !text.endsWith(r'\|')) {
    text = text.substring(0, text.length - 1);
  }
  final cells = <String>[];
  final cell = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (text[i] == r'\' && i + 1 < text.length && text[i + 1] == '|') {
      cell.write('|');
      i++;
    } else if (text[i] == '|') {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(text[i]);
    }
  }
  return cells..add(cell.toString().trim());
}

/// An image alone on its line: `![alt](url)`, optionally with a title.
({String alt, String url})? lineImage(String line) =>
    switch (_image.firstMatch(line)) {
      final match? => (alt: match[1]!, url: match[2]!),
      null => null,
    };

final _image = RegExp(
  r'''^\s*!\[([^\]]*)\]\(\s*(\S+?)(?:\s+"[^"]*")?\s*\)\s*$''',
);
final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _delimiterRow = RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$');

/// A header row with a pipe, followed by a delimiter row with as many
/// cells.
bool _startsTable(List<String> lines, int i) =>
    i + 1 < lines.length &&
    _isRow(lines[i]) &&
    _delimiterRow.hasMatch(lines[i + 1]) &&
    lines[i + 1].contains('-') &&
    (lines[i + 1].contains('|') || lines[i].trim().startsWith('|')) &&
    _cells(lines[i]).length == _cells(lines[i + 1]).length;

bool _isRow(String line) => line.trim().isNotEmpty && line.contains('|');
