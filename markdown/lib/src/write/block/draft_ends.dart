import '../../tree/blocks.dart';
import '../../visible/visible_text.dart';
import '../draft.dart';

/// [block] as a draft that keeps it and all in it.
Draft asDraft(Block block) => switch (block) {
  QuoteBlock() => QuoteDraft.of(block, [
    for (final child in block.children) KeptDraft(child),
  ]),
  ListBlock() => ListDraft.of(block, [
    for (final item in block.items) KeptDraft(item),
  ]),
  ItemBlock() => ItemDraft.of(block, [
    for (final child in block.children) KeptDraft(child),
  ]),
  RootBlock() || LeafBlock() => KeptDraft(block),
};

/// The old block whose end [draft]'s end is.
Block? oldEndOf(Draft draft) => switch (draft) {
  KeptDraft(:final block) => block,
  TextDraft(:final from) => from.lastOrNull,
  CodeDraft(:final from) => from,
  ListDraft(:final from) => from,
  ItemDraft(:final from) => from,
  QuoteDraft(:final from) => from,
};

/// The old block whose start [draft]'s start is.
Block? oldStartOf(Draft draft) => switch (draft) {
  TextDraft(:final from) => from.firstOrNull,
  _ => oldEndOf(draft),
};

/// The old leaf [draft] starts with, if it starts with one.
LeafBlock? firstOldLeaf(Draft draft) => switch (draft) {
  KeptDraft(:final block) => block.leaves.firstOrNull,
  TextDraft(:final from) => from.firstOrNull,
  CodeDraft(:final from) => from,
  ListDraft(:final items) => firstOldLeaf(items.first),
  ItemDraft(:final children) || QuoteDraft(:final children) =>
    children.isEmpty ? null : firstOldLeaf(children.first),
};

/// The old leaf [draft] ends with, if it ends with one.
LeafBlock? lastOldLeaf(Draft draft) => switch (draft) {
  KeptDraft(:final block) => block.leaves.lastOrNull,
  TextDraft(:final from) => from.lastOrNull,
  CodeDraft(:final from) => from,
  ListDraft(:final items) => lastOldLeaf(items.last),
  ItemDraft(:final children) || QuoteDraft(:final children) =>
    children.isEmpty ? null : lastOldLeaf(children.last),
};

/// [leaf] as a draft that says its text anew.
TextDraft restated(TextLeaf leaf) => TextDraft(
  leaf.id,
  visibleTextOf(leaf.text),
  level: leaf is HeadingBlock ? leaf.level : null,
  from: [leaf],
);

/// Whether [draft] is an indented code block, which another right after
/// it would join.
bool isIndentedCode(Draft? draft) => switch (draft) {
  CodeDraft(from: CodeBlock(fenced: false)) ||
  KeptDraft(block: CodeBlock(fenced: false)) => true,
  _ => false,
};

/// Whether [item] starts with an indented code block.
bool startsWithIndentedCode(ItemDraft item) =>
    switch (item.children.firstOrNull) {
      CodeDraft(from: CodeBlock(fenced: false)) ||
      KeptDraft(block: CodeBlock(fenced: false)) => true,
      _ => false,
    };
