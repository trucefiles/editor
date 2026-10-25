import 'package:collection/collection.dart';

import '../tree/blocks.dart';
import '../visible/visible_text.dart';
import 'block/block_writer.dart';
import 'draft.dart';

/// Whether [root], read from the lines a draft wrote, holds what the
/// [draft] says: the same blocks, ids, kinds, text, boxes and code.
bool holdsDraft(RootBlock root, RootDraft draft) =>
    _allMatch(draft.children, root.children);

bool _allMatch(List<Draft> drafts, List<Block> blocks) =>
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
      (TextDraft(level: null, :final text), ParagraphBlock(text: final read)) =>
        visibleTextOf(read).looksLike(text),
      (
        TextDraft(:final level?, :final text),
        HeadingBlock(level: final readLevel, text: final read),
      ) =>
        level == readLevel && visibleTextOf(read).looksLike(text),
      (CodeDraft(:final code), CodeBlock(code: final read)) => code == read,
      (QuoteDraft(:final children), QuoteBlock(children: final read)) =>
        _allMatch(children, read),
      (ListDraft(), final ListBlock list) => _sameList(
        draft as ListDraft,
        list,
      ),
      (
        ItemDraft(:final checked, :final children),
        ItemBlock(checked: final readChecked, children: final read),
      ) =>
        checked == readChecked && _allMatch(children, read),
      _ => false,
    };

bool _sameList(ListDraft draft, ListBlock list) =>
    draft.kind == list.kind &&
    // A loose list may read tight once an edit took its last blank line
    // between items away; a tight one never reads loose.
    (draft.loose || !list.loose) &&
    (draft.kind == ListKind.bullet ||
        list.items.first.marker.number == draft.start) &&
    _allMatch(draft.items, list.items);

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
