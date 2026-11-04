import 'package:collection/collection.dart';

import '../doc/doc_nodes.dart';
import '../tree/blocks.dart' show ListKind;
import '../view/rows.dart';
import '../visible/formatting.dart';
import 'commands/links.dart';
import 'commands/styles.dart';
import 'selection.dart';
import 'typing_style.dart';

/// A kind of block the toolbar can turn the caret's block into.
enum BlockKind { checklist, bullets, numbers, heading, quote }

/// What is on where the caret or the selection is, so the toolbar can
/// show it: the text [formats], whether it is in a [link], and the
/// [blocks] the caret's block is.
final class FormatState {
  const FormatState({
    this.formats = const {},
    this.link = false,
    this.blocks = const {},
  });

  /// Nothing on: no caret.
  static const none = FormatState();

  final Set<TextFormat> formats;
  final bool link;
  final Set<BlockKind> blocks;

  @override
  bool operator ==(Object other) =>
      other is FormatState &&
      const SetEquality<TextFormat>().equals(other.formats, formats) &&
      other.link == link &&
      const SetEquality<BlockKind>().equals(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(
    const SetEquality<TextFormat>().hash(formats),
    link,
    const SetEquality<BlockKind>().hash(blocks),
  );

  @override
  String toString() => 'FormatState($formats, link: $link, $blocks)';
}

/// What is on at [selection] in [view]: at a caret, the formats typing
/// there takes ([typingStyle], the style the user set there, first);
/// over a selection, the formats every character has (the rule that
/// says whether a toggle takes them off). The link is on where all the
/// selection is in one (see [linkHere]); the blocks are those of the
/// selection's end.
FormatState formatStateAt(
  ViewRows view,
  Selection? selection, {
  Formatting? typingStyle,
}) => switch (selection) {
  final TextSelection range => FormatState(
    formats: range.isCaret
        ? (typingStyle ?? typingStyleAt(view.doc, range.extent)).formats
        : {
            for (final format in TextFormat.values)
              if (hasStyle(view, range, format)) format,
          },
    link: linkHere(view, range) != null,
    blocks: _blocksOf(view, range.extent.leaf),
  ),
  BlockSelection() || BlockCaret() || null => FormatState.none,
};

Set<BlockKind> _blocksOf(ViewRows view, NodeId leaf) {
  final path = view.doc.pathOf(leaf);
  final item = path.whereType<ItemNode>().lastOrNull;
  final list = item == null ? null : view.doc.parentOf(item.id);
  return {
    if (item case ItemNode(hasBox: true)) BlockKind.checklist,
    if ((item?.hasBox, list) case (false, ListNode(kind: ListKind.bullet)))
      BlockKind.bullets,
    if ((item?.hasBox, list) case (false, ListNode(kind: ListKind.numbered)))
      BlockKind.numbers,
    if (view.doc.nodeOf(leaf) is HeadingNode) BlockKind.heading,
    if (path.any((node) => node is QuoteNode)) BlockKind.quote,
  };
}
