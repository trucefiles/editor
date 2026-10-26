/// How a text prints: what of it Markdown can write, its links' forms
/// and its spans' delimiters. The writable form and the printer both
/// take a text's layout, so they agree by construction.
library;

import '../read/syntax/block_starts.dart';
import '../tree/blocks.dart';
import '../tree/inlines.dart';
import '../visible/formatting.dart';
import '../visible/visible_text.dart';
import 'char_classes.dart';
import 'escaping.dart';
import 'inline_cells.dart';
import 'links.dart';
import 'spans.dart';

/// A text laid out for printing: [text] is what Markdown can write of the
/// text it was made from, and the rest says how it is written.
final class InlineLayout {
  InlineLayout._(
    this.text,
    this.elements,
    this.forms,
    this.top,
    this.inner,
    this.definitions,
  );

  /// What Markdown can write of the text.
  final VisibleText text;

  /// [text]'s cells, as elements.
  final List<Element> elements;

  /// The form of each element that is a link; `null` for others.
  final List<LinkForm?> forms;

  /// The spans and delimiters among the elements.
  final LevelSpans top;

  /// The spans and delimiters in each bracketed link's text; `null` for
  /// other elements.
  final List<LevelSpans?> inner;

  /// The link definitions its links and images read with.
  final Map<String, LinkDefinition> definitions;
}

/// The layout of [text], a heading's if [heading], with [definitions]
/// and [style]: what Markdown can write of it is kept, the rest goes.
///
/// A line break, line end character or object has no code format, and a
/// heading's objects are in one line; inline HTML that would
/// start an HTML block is text; one at the text's start or end,
/// spaces next to one, a soft break next to another break and spaces at
/// the end go; a heading's hard breaks are spaces. A link that can't be
/// written as it was is written inline; one written bare or between `<`
/// and `>` has no formats of its own. Spans are as [writableSpans] makes
/// them.
InlineLayout layoutOf(
  VisibleText text, {
  required bool heading,
  required Map<String, LinkDefinition> definitions,
  required SpanStyle style,
}) {
  final layout = _laidOut(
    _writableBreaks(cellsOf(text), heading: heading),
    definitions: definitions,
    style: style,
  );
  final merged = cellsOf(layout.text);
  // Taking formats off can join two pieces into one: lay that out anew.
  return merged.length == layout.elements.expand((e) => e.cells).length
      ? layout
      : _laidOut(merged, definitions: definitions, style: style);
}

InlineLayout _laidOut(
  List<Cell> cells, {
  required Map<String, LinkDefinition> definitions,
  required SpanStyle style,
}) {
  final elements = elementsOf(cells);
  final forms = _formsOf(elements, definitions);
  final common = [
    for (final element in elements)
      element.cells
          .map((cell) => cell.spans)
          .reduce((a, b) => a.intersection(b)),
  ];
  final top = writableSpans(
    [
      for (final (index, element) in elements.indexed)
        (
          spans: common[index],
          first:
              forms[index]?.startClass(element.cells.first.first) ??
              element.cells.first.first,
          last:
              forms[index]?.endClass(element.cells.last.last) ??
              element.cells.last.last,
          space: element is PlainElement && element.cell.isSpace,
        ),
    ],
    edge: CharClass.whitespace,
    style: style,
  );
  final inner = [
    for (final (index, element) in elements.indexed)
      if (forms[index]?.bracketed ?? false)
        writableSpans(
          [
            for (final cell in element.cells)
              (
                spans: cell.spans.difference(common[index]),
                first: cell.first,
                last: cell.last,
                space: cell.isSpace,
              ),
          ],
          edge: CharClass.punctuation,
          style: style,
        )
      else
        null,
  ];
  final written = [
    for (final (index, element) in elements.indexed)
      for (final (at, cell) in element.cells.indexed)
        cell.withSpans({...top.spans[index], ...?inner[index]?.spans[at]}),
  ];
  return InlineLayout._(
    textOf(written),
    elementsOf(written),
    forms,
    top,
    inner,
    definitions,
  );
}

/// The form of each link among [elements] (`null` for other elements),
/// each judged by how the text around it prints: the links before it in
/// their forms, those after it as bracketed.
/// [text] with each character that prints as a reference shown as the
/// `;` it ends with, [first] in the text.
String _printedShape(String text, {required bool first}) => [
  for (final (index, rune) in text.runes.indexed)
    if (String.fromCharCode(rune) case final char)
      printsAsReference(char, first: first && index == 0) ? ';' : char,
].join();

List<LinkForm?> _formsOf(
  List<Element> elements,
  Map<String, LinkDefinition> definitions,
) {
  String plainOf(Element element) =>
      element.cells.map((cell) => cell.plain).join();
  final after = [
    for (final element in elements)
      element is LinkElement ? '[${plainOf(element)}]' : plainOf(element),
  ];
  final forms = <LinkForm?>[];
  final before = StringBuffer();
  for (final (index, element) in elements.indexed) {
    final text = plainOf(element);
    if (element is LinkElement) {
      final form = linkFormOf(
        element,
        before: before.toString(),
        after: after.skip(index + 1).join(),
        definitions: definitions,
      );
      forms.add(form);
      before.write(switch (form) {
        LinkForm.bare => text,
        LinkForm.angle => '<$text>',
        LinkForm.inline || LinkForm.reference => '[$text]()',
      });
    } else {
      forms.add(null);
      before.write(_printedShape(text, first: before.isEmpty));
    }
  }
  return forms;
}

/// [cells] with the line breaks and spaces Markdown can write: see
/// [layoutOf].
List<Cell> _writableBreaks(List<Cell> cells, {required bool heading}) {
  final breaks = [
    for (final cell in cells.expand(_codeLineEndsOut))
      switch (cell) {
        BreakCell(isHard: true) when heading => CharCell(
          ' ',
          cell.formatting.withFormat(TextFormat.code, on: false),
        ),
        BreakCell() => BreakCell(
          cell.breakPiece.withFormatting(
            cell.formatting.withFormat(TextFormat.code, on: false),
          ),
        ),
        ObjectCell(:final object) => ObjectCell(
          ObjectPiece(
            heading ? inOneLine(object.inline) : object.inline,
            cell.formatting.withFormat(TextFormat.code, on: false),
          ),
        ),
        _ => cell,
      },
  ];
  final spaced = [
    for (final (index, cell) in breaks.indexed)
      if (!_isSpace(cell) || !_nextToBreak(breaks, index)) cell,
  ];
  final kept = [
    for (final (index, cell) in spaced.indexed)
      if (_keepsBreak(spaced, index)) cell,
  ];
  final start = kept.indexWhere((cell) => cell is! BreakCell);
  if (start < 0) return const [];
  final end =
      kept.lastIndexWhere((cell) => cell is! BreakCell && !_isSpace(cell)) + 1;
  if (end <= start) return const [];
  final trimmed = kept.sublist(start, end);
  return [
    for (final (index, cell) in trimmed.indexed)
      if (_startsHtmlBlock(trimmed, index))
        for (final rune in inOneLine(
          (cell as ObjectCell).object.inline,
        ).source.runes)
          CharCell(String.fromCharCode(rune), cell.formatting)
      else
        cell,
  ];
}

/// Whether the cell at [index] of [cells] is inline HTML that would start
/// an HTML block where it is: at a line's start (see [startsHtmlBlock]).
bool _startsHtmlBlock(List<Cell> cells, int index) {
  final cell = cells[index];
  if (cell is! ObjectCell || cell.object.inline is! HtmlInline) return false;
  if (index > 0 && cells[index - 1] is! BreakCell) return false;
  return startsHtmlBlock(
    cell.object.inline.source,
    alone: index == 0 && (cells.length == 1 || cells[1] is BreakCell),
  );
}

/// Whether inline HTML [source] at a line's start starts an HTML block
/// there, by its first line; a lone tag only if that line holds nothing
/// else: if [source] goes on in lines of its own, or it is [alone] in
/// the text's first line.
bool startsHtmlBlock(String source, {required bool alone}) {
  final first = source.split(lineEnd).first;
  final ownLine = alone || first.length < source.length;
  return htmlBlockStarts.entries.any(
    (start) =>
        (start.key < 7 || ownLine) && start.value.matchAsPrefix(first) != null,
  );
}

/// [cell] with the line end characters of its code out of code: a code
/// span can't hold one.
List<Cell> _codeLineEndsOut(Cell cell) => switch (cell) {
  CodeCell(:final code, :final formatting) when code.contains(_lineEndChar) => [
    for (final part in _codeParts.allMatches(code).map((match) => match[0]!))
      _lineEndChar.hasMatch(part)
          ? CharCell(part, formatting.withFormat(TextFormat.code, on: false))
          : CodeCell(part, formatting),
  ],
  _ => [cell],
};

final _lineEndChar = RegExp('[\r\n]');
final _codeParts = RegExp('[\r\n]|[^\r\n]+');

/// Whether [cell] is a space or tab of text.
bool _isSpace(Cell cell) =>
    cell is CharCell && (cell.char == ' ' || cell.char == '\t');

/// Whether a line break is next to [index] in [cells], past spaces.
bool _nextToBreak(List<Cell> cells, int index) {
  var after = index + 1;
  while (after < cells.length && _isSpace(cells[after])) {
    after++;
  }
  var before = index - 1;
  while (before >= 0 && _isSpace(cells[before])) {
    before--;
  }
  return (after < cells.length && cells[after] is BreakCell) ||
      (before >= 0 && cells[before] is BreakCell);
}

/// Whether the cell at [index] of [cells] stays: of each run of line
/// breaks, its hard ones, or else its first.
bool _keepsBreak(List<Cell> cells, int index) {
  if (cells[index] case BreakCell(isHard: false)) {
    var start = index;
    while (start > 0 && cells[start - 1] is BreakCell) {
      start--;
    }
    var end = index + 1;
    while (end < cells.length && cells[end] is BreakCell) {
      end++;
    }
    final hard = cells
        .sublist(start, end)
        .any((cell) => cell is BreakCell && cell.isHard);
    return !hard && start == index;
  }
  return true;
}
