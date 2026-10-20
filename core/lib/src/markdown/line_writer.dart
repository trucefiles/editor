import 'package:collection/collection.dart';

import 'markdown_line.dart';
import 'outline.dart';
import 'syntax/block_syntax.dart';

/// Writes lines where the document's structure puts them: the one owner
/// of indent characters. Edits decide only where a line goes and at which
/// level ([LinePlace]); this turns that into the line's indent, in the
/// file's own style, as Markdown reads it.
final class LineWriter {
  LineWriter._(this._unit);

  /// The writer for a file whose items have [itemIndents], in its style:
  /// one level is the least of them that is not empty, two spaces if none
  /// is.
  factory LineWriter.of(Iterable<String> itemIndents) => LineWriter._(
    minBy(itemIndents.where((indent) => indent.isNotEmpty), columnsOf) ?? '  ',
  );

  /// One level as this file writes it.
  final String _unit;

  /// [block], an item with the lines under it, written at [place]: the
  /// item gets the indent of its place, and the lines under it follow it
  /// (see [_under]).
  List<MarkdownLine> placed(List<MarkdownLine> block, LinePlace place) {
    final [item, ...under] = block;
    final indent = _indentOf(place);
    return [
      item.withIndent(indent),
      for (final line in under) _under(line, item: item, to: indent),
    ];
  }

  /// [block], an item with the lines under it, once the item changed in
  /// place from [was], e.g. to another kind: if its content now starts
  /// further in, the lines in it move as far in, so they stay in it as
  /// they were; text that continues it lazily stays as it is.
  List<MarkdownLine> inPlace(
    List<MarkdownLine> block, {
    required MarkdownLine was,
  }) {
    final [item, ...under] = block;
    final shift = item.contentColumn - was.contentColumn;
    if (shift <= 0) return block;
    return [
      item,
      for (final line in under)
        line.isBlank || !_reaches(line, was)
            ? line
            : line.withIndent('${line.indent}${' ' * shift}'),
    ];
  }

  String _indentOf(LinePlace place) => switch (place) {
    AtMargin() => '',
    BesideItem(:final item) => item.indent,
    UnderItem(:final item) => '${item.indent}${_offsetUnder(item)}',
  };

  /// What a line one level under [item] adds to the item's indent: this
  /// file's unit if it reaches where the item's content starts, as
  /// Markdown needs, and stays short of four columns past it, where
  /// Markdown would read code; else spaces up to the content.
  String _offsetUnder(MarkdownLine item) {
    final content = item.contentOffset;
    final width = columnsOf(_unit);
    return width >= content && width < content + 4 ? _unit : ' ' * content;
  }

  /// [line], under [item], once the item's indent changes to [to]. A
  /// blank line needs no indent and stays as it is. A line that does not
  /// reach the item's content (text that continues it lazily) lands one
  /// level under it, so it stays the item's wherever it goes. Any other
  /// keeps its indent relative to the item: as written, else (indented
  /// with other characters, e.g. a tab under spaces, or a tab that would
  /// end up narrower) as wide, in spaces.
  MarkdownLine _under(
    MarkdownLine line, {
    required MarkdownLine item,
    required String to,
  }) {
    if (line.isBlank) return line;
    final from = item.indent;
    final deeper = columnsOf(line.indent) - columnsOf(from);
    return line.withIndent(switch (line.indent) {
      _ when !_reaches(line, item) => '$to${_offsetUnder(item)}',
      final indent
          when indent.startsWith(from) &&
              _widthAfter(to, indent.substring(from.length)) == deeper =>
        '$to${indent.substring(from.length)}',
      _ => '$to${' ' * deeper}',
    });
  }

  /// How many columns [rest] adds after [indent]: a tab in it adds less
  /// after an indent that does not end at a tab stop.
  static int _widthAfter(String indent, String rest) =>
      columnsOf('$indent$rest') - columnsOf(indent);

  /// Whether [line] is indented at least to where [item]'s content starts.
  static bool _reaches(MarkdownLine line, MarkdownLine item) =>
      columnsOf(line.indent) >= item.contentColumn;
}
