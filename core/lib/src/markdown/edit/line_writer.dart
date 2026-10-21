import 'package:collection/collection.dart';

import '../document/item_outline.dart';
import '../lines/markdown_line.dart';
import '../tree/block_starts.dart';
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
  /// spaces, so the line lines up with the content after them. [afterBlank]
  /// when a blank line is between them: a task box is the item's content,
  /// so there the line starts where the box does, or it would be code.
  static String continuation(String prefix, {bool afterBlank = false}) =>
      (afterBlank ? prefix.replaceFirst(_trailingBox, '') : prefix).replaceAll(
        _markerCharacter,
        ' ',
      );

  static final _markerCharacter = RegExp(r'[^>\s]');
  static final _trailingBox = RegExp(r'\[[ xX]\][ \t]*$');

  /// The lines that write [content] after the quote marks [outer], a line
  /// an edit took out of a list or a quote, right below the leaf [above]
  /// (none at the top). Below the text of an item or a quote, Markdown
  /// would read the line as more of that text, so a blank line with the
  /// same quote marks goes first.
  static List<String> outOfContainer(
    String outer,
    String content, {
    required LeafBlock? above,
  }) => [
    if (above is ParagraphBlock &&
        (above.parent is ItemBlock || above.parent is QuoteBlock))
      outer.trimRight(),
    content.isEmpty ? outer.trimRight() : '$outer$content',
  ];

  /// An item's line: [prefix] (its quote marks and indent), [marker] (as
  /// [ItemStyle] writes it) and [content].
  static String itemLine(String prefix, String marker, String content) =>
      withContent('$prefix$marker', content);

  /// A line with [prefix] and then [content]. A marker that ends the
  /// prefix gets a space before content, as Markdown needs.
  static String withContent(String prefix, String content) =>
      content.isEmpty ||
          prefix.isEmpty ||
          isSpaceOrTab(prefix[prefix.length - 1])
      ? '$prefix$content'
      : '$prefix $content';

  /// The prefix of a new item's line at [place], up to its marker.
  String itemPrefix(ItemOutline outline, LinePlace place) {
    final (:outer, :indent) = _placeAt(outline, place);
    return '$outer$indent';
  }

  /// [lines], the lines of [item]'s block in the document [source]
  /// knows, written at [place] among the lines [target] knows: the item
  /// gets the indent of its place, and the lines in it follow it. Where
  /// it starts a new list, a number there starts it at 1.
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
    final marked = source.partsOf(item, first).rest;
    return [
      '$outer$indent${_opensList(item, place) ? _opening(marked) : marked}',
      for (final line in rest)
        switch (source.partsOf(item, line)) {
          final parts when parts.rest.trim().isEmpty => _blank(
            parts.outer,
            line.raw,
            outer: outer,
          ),
          final parts => _under(
            source,
            item,
            line,
            parts,
            outer: outer,
            from: from,
            to: indent,
          ),
        },
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

  /// [line] of [item]'s block, cut as [parts], once the item's indent
  /// changes from [from] to [to] after [outer]: it keeps its indent
  /// relative to the item, as written, else (indented with other
  /// characters, e.g. a tab under spaces) as wide, in spaces. A line that
  /// does not reach the item's content (text that continues the innermost
  /// item it is in lazily) lands one level under that item, so it stays
  /// its text wherever it goes; indented four columns or more, it keeps
  /// that width there, in spaces, so it still reads as text.
  String _under(
    ItemOutline source,
    ItemBlock item,
    MarkdownLine line,
    ItemLineParts parts, {
    required String outer,
    required String from,
    required String to,
  }) {
    if (!parts.reaches) {
      final inner = source.itemsAt(line.id).first;
      final under = _deeper(source.partsOf(item, inner.firstLine), from);
      final width = _width(parts.outer, parts.indent);
      return '$outer$to${' ' * under}${_offsetUnder(source.paddingOf(inner))}'
          '${width >= 4 ? ' ' * width : ''}${parts.rest}';
    }
    final deeper = _deeper(parts, from);
    final indent =
        parts.indent.startsWith(from) &&
            _width(outer + to, parts.indent.substring(from.length)) == deeper
        ? '$to${parts.indent.substring(from.length)}'
        : '$to${' ' * deeper}';
    return '$outer$indent${parts.rest}';
  }

  /// How many columns further than [from] the indent of [line] reaches.
  static int _deeper(ItemLineParts line, String from) =>
      _width(line.outer, line.indent) - _width(line.outer, from);

  /// Whether [item] put at [place] starts a list of its own: in no list
  /// there, or beside an item of another list.
  static bool _opensList(ItemBlock item, LinePlace place) => switch (place) {
    BesideItem(item: final sibling) => !sibling.marker.sameListAs(item.marker),
    AtMargin() || UnderItem() => true,
  };

  /// [rest], an item's line from its marker on, as the first item of a
  /// new list: numbered from 1, as Markdown needs for a list that starts
  /// right below text.
  static String _opening(String rest) =>
      switch (numberedMarker.matchAsPrefix(rest)) {
        final match? => rest.replaceRange(0, match[1]!.length, '1'),
        null => rest,
      };

  /// A line [raw] of a moved item that is blank after its quote marks
  /// [from], once the item lands after [outer]: as it is if it stays in
  /// the same quotes, else just their marks.
  static String _blank(String from, String raw, {required String outer}) =>
      from.trimRight() == outer.trimRight() ? raw : outer.trimRight();

  /// How many columns [text] takes after [before].
  static int _width(String before, String text) =>
      columnsOf(text, columnsOf(before)) - columnsOf(before);
}
