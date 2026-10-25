/// What an edit says a note's blocks become: the new structure (text,
/// kind, box, level, place), never file text. The writer turns it into
/// lines, keeping each line's own style.
library;

import '../tree/blocks.dart';
import '../visible/visible_text.dart';

/// One block as an edit wants it.
sealed class Draft {
  const Draft();

  BlockId get id;
}

/// A block as it is, wherever the draft puts it.
final class KeptDraft extends Draft {
  const KeptDraft(this.block);

  final Block block;

  @override
  BlockId get id => block.id;
}

/// A paragraph, or a heading of [level], showing [text]. [from] are the
/// leaves its text comes from, in order (two for a join), whose spelling
/// it keeps where its text is theirs.
final class TextDraft extends Draft {
  const TextDraft(this.id, this.text, {this.level, this.from = const []});

  @override
  final BlockId id;

  final VisibleText text;

  /// The heading level, 1 to 6; `null` for a paragraph.
  final int? level;

  final List<TextLeaf> from;
}

/// A code block whose code is now [code].
final class CodeDraft extends Draft {
  const CodeDraft(this.from, this.code);

  final CodeBlock from;
  final String code;

  @override
  BlockId get id => from.id;
}

/// A list of [kind] whose items are [ItemDraft]s or kept items.
final class ListDraft extends Draft {
  ListDraft(
    this.id,
    List<Draft> items, {
    required this.kind,
    required this.loose,
    this.numbering = Numbering.sequential,
    this.start = 1,
    this.from,
  }) : items = List.unmodifiable(items),
       assert(items.isNotEmpty, 'a list holds an item'),
       assert(
         items.every(
           (item) =>
               item is ItemDraft ||
               (item is KeptDraft && item.block is ItemBlock),
         ),
         'a list holds items',
       );

  /// [list] with [items] instead: its kind, spacing and numbering.
  ListDraft.of(ListBlock list, List<Draft> items)
    : this(
        list.id,
        items,
        kind: list.kind,
        loose: list.loose,
        numbering: list.numbering,
        start: list.items.first.marker.number ?? 1,
        from: list,
      );

  @override
  final BlockId id;

  final List<Draft> items;
  final ListKind kind;
  final bool loose;
  final Numbering numbering;

  /// The number of a numbered list's first item.
  final int start;

  /// The list it was, whose markers it keeps.
  final ListBlock? from;
}

/// A list item holding [children]; [checked] says its box, `null` for
/// none.
final class ItemDraft extends Draft {
  ItemDraft(this.id, List<Draft> children, {this.checked, this.from})
    : children = List.unmodifiable(children);

  /// [item] with [children] instead, and its box unless [checked] says
  /// otherwise.
  ItemDraft.of(ItemBlock item, List<Draft> children, {bool? checked})
    : this(item.id, children, checked: checked ?? item.checked, from: item);

  @override
  final BlockId id;

  final List<Draft> children;
  final bool? checked;

  /// The item it was, whose marker it keeps.
  final ItemBlock? from;
}

/// A block quote holding [children].
final class QuoteDraft extends Draft {
  QuoteDraft(this.id, List<Draft> children, {this.from})
    : children = List.unmodifiable(children);

  /// [quote] with [children] instead.
  QuoteDraft.of(QuoteBlock quote, List<Draft> children)
    : this(quote.id, children, from: quote);

  @override
  final BlockId id;

  final List<Draft> children;

  /// The quote it was, whose marks it keeps.
  final QuoteBlock? from;
}

/// The whole note: [children] in [root]'s place.
final class RootDraft {
  RootDraft(this.root, List<Draft> children)
    : children = List.unmodifiable(children);

  final RootBlock root;
  final List<Draft> children;
}
