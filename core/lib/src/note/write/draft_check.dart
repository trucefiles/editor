import 'package:collection/collection.dart';

import '../note_tree.dart';
import '../tree/blocks.dart';
import '../visible/visible_text.dart';
import 'block/block_writer.dart';
import 'draft.dart';

/// Whether [tree], read from the lines a draft wrote, holds what the
/// [draft] says: the same blocks, ids, kinds, text, boxes and code.
bool holdsDraft(NoteTree tree, RootDraft draft) =>
    _Check(tree).allMatch(draft.children, tree.root.children);

final class _Check {
  _Check(this._tree);

  final NoteTree _tree;

  bool allMatch(List<Draft> drafts, List<Block> blocks) =>
      drafts.length == blocks.length &&
      IterableZip([drafts, blocks])
          .every((pair) => _matches(pair[0] as Draft, pair[1] as Block));

  bool _matches(Draft draft, Block block) =>
      draft.id == block.id &&
      switch ((draft, block)) {
        (KeptDraft(block: final LeafBlock old), final LeafBlock leaf) =>
          _sameLeaf(old, leaf),
        (KeptDraft(block: final ContainerBlock old), _) => _matches(
          asDraft(old),
          block,
        ),
        (
          TextDraft(level: null, :final text),
          ParagraphBlock(text: final read),
        ) =>
          visibleTextOf(read).looksLike(text),
        (
          TextDraft(:final level?, :final text),
          HeadingBlock(level: final readLevel, text: final read),
        ) =>
          level == readLevel && visibleTextOf(read).looksLike(text),
        (CodeDraft(:final code), CodeBlock(code: final read)) => code == read,
        (QuoteDraft(:final children), QuoteBlock(children: final read)) =>
          allMatch(children, read),
        (ListDraft(), final ListBlock list) => _sameList(
          draft as ListDraft,
          list,
        ),
        (
          ItemDraft(:final checked, :final children),
          ItemBlock(checked: final readChecked, children: final read),
        ) =>
          checked == readChecked && allMatch(children, read),
        _ => false,
      };

  bool _sameList(ListDraft draft, ListBlock list) =>
      draft.kind == list.kind &&
      // A loose list may read tight once an edit took its last blank line
      // between items away; a tight one reads loose only where an item's
      // blocks need a blank line between them.
      (draft.loose || !list.loose || list.items.any(_blankInside)) &&
      (draft.kind == ListKind.bullet ||
          list.items.first.marker.number == draft.start) &&
      allMatch(draft.items, list.items);

  /// Whether a blank line comes between two of [item]'s blocks.
  bool _blankInside(ItemBlock item) =>
      IterableZip([item.children, item.children.skip(1)]).any(
        (pair) =>
            _tree.indexOf(lineSpanOf(pair[1]).first) >
            _tree.indexOf(lineSpanOf(pair[0]).last) + 1,
      );
}

/// Whether [leaf] says what [old] said, which a draft kept: the same
/// content, which may now read otherwise (a reference whose definition
/// moved), or text written anew that shows the same.
bool _sameLeaf(LeafBlock old, LeafBlock leaf) =>
    old.runtimeType == leaf.runtimeType &&
    switch ((old, leaf)) {
      (TextLeaf(text: final a), TextLeaf(text: final b))
          when visibleTextOf(a).looksLike(visibleTextOf(b)) =>
        true,
      (CodeBlock(code: final a), CodeBlock(code: final b)) => a == b,
      _ => const ListEquality<String>().equals(
        [for (final line in old.lines) line.content],
        [for (final line in leaf.lines) line.content],
      ),
    };
