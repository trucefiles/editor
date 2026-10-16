import 'package:truce_core/truce_core.dart';

/// What the list view shows: a checkbox item, or the lines between items
/// as one block of Markdown.
sealed class ChecklistBlock {
  const ChecklistBlock();

  /// The block's first line; identifies it in the list.
  ChecklistLine get first;
}

final class ItemBlock extends ChecklistBlock {
  const ItemBlock(this.first);

  @override
  final ChecklistLine first;
}

final class TextBlock extends ChecklistBlock {
  const TextBlock(this.lines);

  final List<ChecklistLine> lines;

  @override
  ChecklistLine get first => lines.first;

  String get markdown => lines.map((line) => line.raw).join('\n');
}

/// Splits [lines] into items and runs of other lines. Runs of only blank
/// lines are left out.
List<ChecklistBlock> blocksOf(Iterable<ChecklistLine> lines) {
  final blocks = <ChecklistBlock>[];
  var text = <ChecklistLine>[];
  void endText() {
    if (text.any((line) => line.raw.trim().isNotEmpty)) {
      blocks.add(TextBlock(text));
    }
    text = [];
  }

  for (final line in lines) {
    if (line.isItem) {
      endText();
      blocks.add(ItemBlock(line));
    } else {
      text.add(line);
    }
  }
  endText();
  return blocks;
}

/// [blocks] split around their items, so add rows can sit just above the
/// first item and just below the last: [head] is the text above the first
/// item, [body] the items with all in between, and [tail] the text below
/// the last item, except text indented right below it, which is part of
/// it. Without items, all is [head].
({
  List<ChecklistBlock> head,
  List<ChecklistBlock> body,
  List<ChecklistBlock> tail,
})
splitAtItems(List<ChecklistBlock> blocks) {
  final first = blocks.indexWhere((block) => block is ItemBlock);
  if (first < 0) return (head: blocks, body: const [], tail: const []);
  var end = blocks.lastIndexWhere((block) => block is ItemBlock) + 1;
  if (end < blocks.length && _isIndentedBelow(blocks[end].first)) end++;
  return (
    head: blocks.sublist(0, first),
    body: blocks.sublist(first, end),
    tail: blocks.sublist(end),
  );
}

/// Whether [line], right below an item, is indented text that goes with it.
bool _isIndentedBelow(ChecklistLine line) =>
    line.raw.trim().isNotEmpty && line.indent.isNotEmpty;
