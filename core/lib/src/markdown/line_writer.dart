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

  /// The writer for a file of [lines], in its style: one level is the
  /// least indent of its indented items, two spaces if none is.
  factory LineWriter.of(List<MarkdownLine> lines) => LineWriter._(
    minBy([
          for (final line in lines)
            if (line.isListItem && line.indent.isNotEmpty) line.indent,
        ], indentWidth) ??
        '  ',
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
    final width = indentWidth(_unit);
    return width >= content && width < content + 4 ? _unit : ' ' * content;
  }

  /// [line], under [item], once the item's indent changes to [to]. A
  /// blank line needs no indent and stays as it is. A line no deeper than
  /// the item (text that continues it without indent) lands one level
  /// under it, so it stays the item's wherever it goes. Any other keeps
  /// its indent relative to the item: as written, else (indented with
  /// other characters, e.g. a tab under spaces) as wide, in spaces.
  MarkdownLine _under(
    MarkdownLine line, {
    required MarkdownLine item,
    required String to,
  }) {
    if (line.isBlank) return line;
    final from = item.indent;
    final deeper = indentWidth(line.indent) - indentWidth(from);
    return line.withIndent(switch (line.indent) {
      _ when deeper <= 0 => '$to${_offsetUnder(item)}',
      final indent when indent.startsWith(from) =>
        '$to${indent.substring(from.length)}',
      _ => '$to${' ' * deeper}',
    });
  }
}
