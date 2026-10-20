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

/// A line of a heading written as text over a line of `===` or `---`:
/// the heading's [level], and whether it [isUnderline] or the text.
typedef UnderlinedHeadingLine = ({int level, bool isUnderline});

/// Whether [header] and [delimiter], two lines one below the other,
/// start a table: a header row with a pipe, then a delimiter row with as
/// many cells.
bool startsTable(String header, String delimiter) =>
    isTableRow(header) &&
    _delimiterRow.hasMatch(delimiter) &&
    delimiter.contains('-') &&
    (delimiter.contains('|') || header.trim().startsWith('|')) &&
    _cells(header).length == _cells(delimiter).length;

/// Whether [line] can be a table's row: not blank, with a pipe.
bool isTableRow(String line) => line.trim().isNotEmpty && line.contains('|');

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
final _delimiterRow = RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$');
