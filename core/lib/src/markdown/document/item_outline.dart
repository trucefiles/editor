import 'package:collection/collection.dart';

import '../lines/line_id.dart';
import '../lines/markdown_line.dart';
import '../tree/blocks.dart';
import '../tree/characters.dart';
import 'markdown_document.dart';

/// The lines from [start] to [end] (exclusive) of a document, by index.
typedef LineSpan = ({int start, int end});

/// Where a line put at a level lands, by the lines around it: [depth] is
/// the level it gets.
sealed class LinePlace {
  const LinePlace(this.depth);

  final int depth;
}

/// Under no item, after [outer]: the marks of the quotes it is in, as
/// written on a line there.
final class AtMargin extends LinePlace {
  const AtMargin([this.outer = '']) : super(0);

  final String outer;
}

/// Beside [item], at its level.
final class BesideItem extends LinePlace {
  const BesideItem(this.item, super.depth);

  final ItemBlock item;
}

/// One level under [item].
final class UnderItem extends LinePlace {
  const UnderItem(this.item, super.depth);

  final ItemBlock item;
}

/// One line of an item's block, cut where its item's place shows: the
/// marks of the quotes the item is in ([outer]), its indent from there
/// ([indent]: whitespace, and the markers of items that start on the
/// same line), and the [rest]. [reaches] tells whether the line is in
/// the item by its indent, not by continuing its text lazily.
typedef ItemLineParts = ({
  String outer,
  String indent,
  String rest,
  bool reaches,
});

/// The list items of a document and where lines go among them, read
/// once from its tree. Every question is a lookup.
final class ItemOutline {
  ItemOutline(this._document);

  final MarkdownDocument _document;

  /// Every list item, in file order.
  late final List<ItemBlock> items = [
    for (final leaf in _document.leaves)
      for (final item
          in leaf.ancestors.whereType<ItemBlock>().toList().reversed)
        if (item.leaves.first == leaf) item,
  ];

  late final Map<LineId, ItemBlock> _byMarkerLine = {
    for (final item in items) item.markerLine: item,
  };

  /// The item whose marker is on line [id]; `null` if none is.
  ItemBlock? itemOf(LineId id) => _byMarkerLine[id];

  /// Nesting level of [item]: the number of items it is in.
  int depthOf(ItemBlock item) => item.ancestors.whereType<ItemBlock>().length;

  /// The items line [id] is in or starts, innermost first.
  List<ItemBlock> itemsAt(LineId id) => [
    ?itemOf(id),
    for (final item in _document.leafOf(id).ancestors.whereType<ItemBlock>())
      if (item.markerLine != id) item,
  ];

  /// Nesting level of line [id]: the number of items it is under; an
  /// item's marker line is under the items its item is in.
  int lineDepth(LineId id) => switch (itemOf(id)) {
    final item? => depthOf(item),
    null => itemsAt(id).length,
  };

  /// The items of the list [item] is in, in file order.
  List<ItemBlock> listOf(ItemBlock item) => (item.parent! as ListBlock).items;

  /// The item that [item] is in that is in no item; [item] itself if it
  /// is in none.
  ItemBlock marginItemOf(ItemBlock item) =>
      item.ancestors.whereType<ItemBlock>().lastOrNull ?? item;

  /// [item]'s lines: from its marker line to its last line that is not
  /// blank.
  LineSpan subtree(ItemBlock item) {
    final last = item.leaves.lastWhere(
      (leaf) => leaf is! BlankBlock,
      orElse: () => item.leaves.first,
    );
    return (
      start: _document.indexOf(item.markerLine),
      end: _document.indexOf(last.lines.last.id) + 1,
    );
  }

  /// The number a numbered [item] shows: as in Markdown, its list counts
  /// on from its first item's number, whatever the others say.
  int? numberOf(ItemBlock item) {
    final list = listOf(item);
    final first = list.first.marker.number;
    return first == null ? null : first + list.indexOf(item);
  }

  /// Lines of checked items and of every line in them (their subitems),
  /// which an editor shows as done together.
  late final Set<LineId> doneIds = {
    for (final item in items)
      if (item.isChecked) ..._idsIn(subtree(item)),
  };

  Iterable<LineId> _idsIn(LineSpan span) =>
      _document.lines.sublist(span.start, span.end).map((line) => line.id);

  /// [line], a line of [item]'s block, cut as [ItemLineParts] says.
  ItemLineParts partsOf(ItemBlock item, MarkdownLine line) {
    final segments = _document.leafOf(line.id).lineOf(line.id).prefix;
    final quotes = item.ancestors.whereType<QuoteBlock>().toSet();
    final outerEnd = segments
        .where((segment) => quotes.contains(segment.container))
        .map((segment) => segment.end)
        .fold(0, (end, next) => next > end ? next : end);
    final own = segments.where((segment) => segment.container == item);
    final raw = line.raw;
    final restStart = line.id == item.markerLine
        ? _markerStart(raw, own.first.start)
        : _indentEnd(raw, outerEnd);
    return (
      outer: raw.substring(0, outerEnd),
      indent: raw.substring(outerEnd, restStart),
      rest: raw.substring(restStart),
      reaches: own.isNotEmpty,
    );
  }

  /// How far [item]'s content starts after its marker, in columns.
  int paddingOf(ItemBlock item) => item.contentColumn - item.markerColumn;

  /// Where a line put at [index], between the lines before it and the
  /// line now there, lands at [depth], as deep as Markdown lets it there:
  /// beside the first line from [index] on that is not blank, if it
  /// starts an item at that depth, so that item stays beside it; else
  /// beside the item at that depth that the nearest line above is in or
  /// starts; else at the margin for the top level; else under the
  /// deepest item that line is in or starts; else at the margin. The one
  /// owner of where a level puts a line.
  LinePlace placeAt(int index, int depth) {
    final lines = _document.lines;
    final below = lines.skip(index).where((line) => !line.isBlank).firstOrNull;
    if (below != null) {
      if (itemOf(below.id) case final item? when depthOf(item) == depth) {
        return BesideItem(item, depth);
      }
    }
    final above = lines.take(index).where((line) => !line.isBlank).lastOrNull;
    final chain = above == null ? const <ItemBlock>[] : itemsAt(above.id);
    return switch ((
      chain.where((item) => depthOf(item) == depth).firstOrNull,
      chain.firstOrNull,
    )) {
      (final sibling?, _) => BesideItem(sibling, depth),
      _ when depth == 0 => AtMargin(marginOuterOf(above)),
      (null, final parent?) => UnderItem(parent, depthOf(parent) + 1),
      _ => AtMargin(marginOuterOf(above)),
    };
  }

  /// The marks of the quotes [line] is in that are in no item, as written
  /// there: where a line at the margin next to it starts.
  String marginOuterOf(MarkdownLine? line) {
    if (line == null) return '';
    final leaf = _document.leafOf(line.id);
    final quotes = {
      for (final quote in leaf.ancestors.whereType<QuoteBlock>())
        if (!quote.ancestors.any((block) => block is ItemBlock)) quote,
    };
    final end = leaf
        .lineOf(line.id)
        .prefix
        .where((segment) => quotes.contains(segment.container))
        .map((segment) => segment.end)
        .fold(0, (end, next) => next > end ? next : end);
    return line.raw.substring(0, end);
  }

  static int _markerStart(String raw, int from) => _indentEnd(raw, from);

  static int _indentEnd(String raw, int from) {
    var index = from;
    while (index < raw.length && isSpaceOrTab(raw[index])) {
      index++;
    }
    return index;
  }
}
