import 'package:collection/collection.dart';

import '../document/item_outline.dart';
import '../lines/markdown_line.dart';
import '../tree/blocks.dart';
import '../tree/characters.dart';

/// Writes lines where the document's structure puts them: the one owner
/// of the prefixes edits give lines (quote marks, indents, markers kept
/// or turned to spaces). Edits decide only what a line holds, where it
/// goes and at which level ([LinePlace]); this turns that into the line's
/// prefix, in the file's own style, as Markdown reads it.
final class LineWriter {
  LineWriter._(this._unit);

  /// The writer for the file whose items [outline] knows, in its style:
  /// one level is the least item indent that is not empty, two spaces if
  /// none is.
  factory LineWriter.of(ItemOutline outline) => LineWriter._(
    minBy(
          [
            for (final item in outline.items)
              outline.partsOf(item, item.firstLine).indent,
          ].where((indent) => indent.isNotEmpty && isBlankText(indent)),
          columnsOf,
        ) ??
        '  ',
  );

  /// One level as this file writes it.
  final String _unit;

  /// The prefix a new line gets below a line with [prefix], to go on in
  /// the same blocks: quote marks stay, markers and boxes turn into
  /// spaces, so the line lines up with the content after them.
  static String continuation(String prefix) =>
      prefix.replaceAll(_markerCharacter, ' ');

  static final _markerCharacter = RegExp(r'[^>\s]');

  /// A line with [prefix] and then [content]. A marker that ends the
  /// prefix gets a space before content, as Markdown needs.
  static String withContent(String prefix, String content) =>
      content.isEmpty || prefix.isEmpty || isSpaceOrTab(prefix[prefix.length - 1])
      ? '$prefix$content'
      : '$prefix $content';

  /// The prefix of a new item's line at [place], up to its marker.
  String itemPrefix(ItemOutline outline, LinePlace place) {
    final (:outer, :indent) = _placeAt(outline, place);
    return '$outer$indent';
  }

  /// [lines], the lines of [item]'s block in the document [source]
  /// knows, written at [place] among the lines [target] knows: the item
  /// gets the indent of its place, and the lines in it follow it.
  List<String> placed(
    ItemOutline source,
    ItemBlock item,
    List<MarkdownLine> lines,
    ItemOutline target,
    LinePlace place,
  ) {
    final (:outer, :indent) = _placeAt(target, place);
    final [first, ...rest] = lines;
    final from = source.partsOf(item, first).indent;
    return [
      '$outer$indent${source.partsOf(item, first).rest}',
      for (final line in rest)
        if (line.isBlank)
          outer.trimRight()
        else
          _under(
            source.partsOf(item, line),
            outer: outer,
            from: from,
            to: indent,
            padding: source.paddingOf(item),
          ),
    ];
  }

  /// [lines], the lines of [item]'s block, once its marker changed in
  /// place to one [shift] columns wider, e.g. bulleted to numbered: the
  /// lines in it move as far in, so they stay in it; text that continues
  /// it lazily stays as it is.
  List<String> shifted(
    ItemOutline outline,
    ItemBlock item,
    List<MarkdownLine> lines,
    int shift,
  ) => [
    for (final (index, line) in lines.indexed)
      if (index == 0 || shift <= 0 || line.isBlank)
        line.raw
      else
        switch (outline.partsOf(item, line)) {
          (:final outer, :final indent, :final rest, reaches: true) =>
            '$outer$indent${' ' * shift}$rest',
          _ => line.raw,
        },
  ];

  /// Where a line at [place] starts: the quote marks before it and its
  /// indent after them.
  ({String outer, String indent}) _placeAt(
    ItemOutline outline,
    LinePlace place,
  ) => switch (place) {
    AtMargin(:final outer) => (outer: continuation(outer), indent: ''),
    BesideItem(:final item) => _startOf(outline, item),
    UnderItem(:final item) => switch (_startOf(outline, item)) {
      (:final outer, :final indent) => (
        outer: outer,
        indent: '$indent${_offsetUnder(outline.paddingOf(item))}',
      ),
    },
  };

  ({String outer, String indent}) _startOf(
    ItemOutline outline,
    ItemBlock item,
  ) {
    final parts = outline.partsOf(item, item.firstLine);
    return (
      outer: continuation(parts.outer),
      indent: continuation(parts.indent),
    );
  }

  /// What a line one level under an item whose content starts [padding]
  /// columns after its marker adds to the item's indent: this file's unit
  /// if it reaches the content, as Markdown needs, and stays short of four
  /// columns past it, where Markdown would read code; else spaces up to
  /// the content.
  String _offsetUnder(int padding) {
    final width = columnsOf(_unit);
    return width >= padding && width < padding + 4 ? _unit : ' ' * padding;
  }

  /// A line in an item, once the item's indent changes from [from] to
  /// [to] after [outer]. A line that does not reach the item's content
  /// (text that continues it lazily) lands one level under it, so it
  /// stays the item's wherever it goes. Any other keeps its indent
  /// relative to the item: as written, else (indented with other
  /// characters, e.g. a tab under spaces) as wide, in spaces.
  String _under(
    ItemLineParts line, {
    required String outer,
    required String from,
    required String to,
    required int padding,
  }) {
    if (!line.reaches) return '$outer$to${_offsetUnder(padding)}${line.rest}';
    final deeper = _width(line.outer, line.indent) - _width(line.outer, from);
    final indent = line.indent.startsWith(from) &&
            _width(outer + to, line.indent.substring(from.length)) ==
                deeper
        ? '$to${line.indent.substring(from.length)}'
        : '$to${' ' * deeper}';
    return '$outer$indent${line.rest}';
  }

  /// How many columns [text] takes after [before].
  static int _width(String before, String text) =>
      columnsOf(text, columnsOf(before)) - columnsOf(before);
}
