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
