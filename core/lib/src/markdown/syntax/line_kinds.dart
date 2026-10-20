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
List<LineKind> lineKinds(List<String> lines) => [..._kindsOf(lines)];

/// The kinds of [lines], read one run at a time: a code block, a table,
/// or a plain line.
Iterable<LineKind> _kindsOf(List<String> lines) sync* {
  var start = 0;
  while (start < lines.length) {
    final run =
        _codeBlockAt(lines, start) ??
        _tableAt(lines, start) ??
        const [LineKind.plain];
    yield* run;
    start += run.length;
  }
}

/// The kinds of the fenced code block that opens at [start], up to its
/// closing fence or the end; `null` if none opens there.
List<LineKind>? _codeBlockAt(List<String> lines, int start) {
  final fence = _fence.firstMatch(lines[start])?.group(1);
  if (fence == null) return null;
  final close = lines.indexWhere((line) => _closes(fence, line), start + 1);
  final end = close < 0 ? lines.length : close;
  return [
    LineKind.fence,
    ...List.filled(end - start - 1, LineKind.code),
    if (close >= 0) LineKind.fence,
  ];
}

/// Whether [line] closes a code block opened with [fence]: a fence of the
/// same character, at least as long, alone on its line.
bool _closes(String fence, String line) =>
    switch (_fence.firstMatch(line)?.group(1)) {
      final closing? =>
        closing[0] == fence[0] &&
            closing.length >= fence.length &&
            line.trim() == closing,
      null => false,
    };

/// The kinds of the table that starts at [start]: its header, delimiter
/// row and the rows right below; `null` if none starts there.
List<LineKind>? _tableAt(List<String> lines, int start) {
  if (!_startsTable(lines, start)) return null;
  final after = lines.indexWhere((line) => !_isRow(line), start + 2);
  final end = after < 0 ? lines.length : after;
  return List.filled(end - start, LineKind.table);
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
  return [
    for (final cell in text.split(_unescapedPipe))
      cell.replaceAll(r'\|', '|').trim(),
  ];
}

final _unescapedPipe = RegExp(r'(?<!\\)\|');

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
