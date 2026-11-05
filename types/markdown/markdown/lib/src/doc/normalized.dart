import '../read/syntax/block_starts.dart';
import '../visible/visible_text.dart';
import 'doc_nodes.dart';
import 'doc_tree.dart';

/// [tree] as Visual edit shows it: every item starts with a text place
/// (an empty paragraph where it is empty or starts with a list), a list
/// without items and a quote without blocks go, and the document ends
/// with text to type in: an empty paragraph follows where its last leaf
/// is none, code or a block without text (unless an HTML block takes in
/// all that would follow). Nodes
/// that need none of this stay the same objects; new paragraphs take
/// ids from [fresh]. [tree] made by an edit of [before], a tree as Visual
/// edit shows it, needs this only in the nodes the edit rebuilt: only
/// those are looked at.
DocTree normalized(DocTree tree, FreshIds fresh, {DocTree? before}) {
  final root = _Normalize(fresh, before).root(tree.root);
  return identical(root, tree.root) ? tree : DocTree(root, nextId: fresh.next);
}

/// An empty paragraph with an id from [fresh].
ParagraphNode emptyParagraph(FreshIds fresh) =>
    ParagraphNode(fresh.take(), VisibleText.empty);

final class _Normalize {
  _Normalize(this._fresh, this._before);

  final FreshIds _fresh;

  /// The tree the one normalized was edited from, as Visual edit shows it.
  final DocTree? _before;

  DocRoot root(DocRoot root) {
    final children = _children(root.children);
    final last = children.lastOrNull;
    final ended = switch ((last, last == null ? null : _lastLeafOf(last))) {
      (null, _) => [emptyParagraph(_fresh)],
      (_, TextNode()) => children,
      (final RawNode raw, _) when takesInTheRest(raw) => children,
      _ => [...children, emptyParagraph(_fresh)],
    };
    return identical(ended, root.children) ? root : root.withChildren(ended);
  }

  /// The last leaf in [block], by its last children; `null` if it ends in
  /// an empty container.
  static DocLeaf? _lastLeafOf(DocBlock block) => switch (block) {
    DocLeaf() => block,
    DocContainer(:final children) => switch (children.lastOrNull) {
      final last? => _lastLeafOf(last),
      null => null,
    },
  };

  /// [children] normalized: the same list if none changed. A child the
  /// tree before holds is as Visual edit shows it already.
  List<DocBlock> _children(List<DocBlock> children) {
    final normalized = [
      for (final child in children)
        if (_before?.holds(child) ?? false) child else ?_block(child),
    ];
    return normalized.length == children.length &&
            Iterable<int>.generate(children.length)
                .every((index) => identical(normalized[index], children[index]))
        ? children
        : normalized;
  }

  DocBlock? _block(DocBlock block) => switch (block) {
    DocLeaf() => block,
    DocRoot() => throw ArgumentError.value(block, 'block', 'a root inside'),
    ListNode() => switch (_children(block.children)) {
      [] => null,
      final items when identical(items, block.children) => block,
      final items => block.withChildren(items),
    },
    QuoteNode() => switch (_children(block.children)) {
      [] => null,
      final children when identical(children, block.children) => block,
      final children => block.withChildren(children),
    },
    ItemNode() => switch (_children(block.children)) {
      final children when children.isEmpty || children.first is ListNode =>
        block.withChildren([emptyParagraph(_fresh), ...children]),
      final children when identical(children, block.children) => block,
      final children => block.withChildren(children),
    },
  };
}

/// Whether [raw] is HTML that takes in all lines after it: it starts as
/// an HTML block that only its end condition closes, and none ends it.
bool takesInTheRest(RawNode raw) {
  if (raw.kind != RawKind.html) return false;
  final lines = raw.raw.split('\n');
  final start = lines.first.trimLeft();
  final kind = htmlBlockEnds.keys
      .where((kind) => htmlBlockStarts[kind]!.matchAsPrefix(start) != null)
      .firstOrNull;
  if (kind == null) return false;
  return !lines.any(htmlBlockEnds[kind]!.hasMatch);
}
