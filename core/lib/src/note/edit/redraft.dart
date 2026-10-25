import '../note_tree.dart';
import '../tree/blocks.dart';
import '../write/block/block_writer.dart';
import '../write/draft.dart';

/// The draft of [tree]'s note with [replaced] blocks: each block with an
/// entry becomes its drafts (none to remove it), and the root's entry
/// is its children; containers with such a block in them are drafted
/// anew around it; all else is kept. A kept block among an entry's
/// drafts takes its own entry, if it has one, except the very block the
/// entry is for (which a draft may wrap).
RootDraft redrafted(NoteTree tree, Map<BlockId, List<Draft>> replaced) {
  final redraft = _Redraft(tree, replaced);
  return RootDraft(tree.root, [
    for (final child
        in replaced[tree.root.id] ??
            [for (final child in tree.root.children) KeptDraft(child)])
      ...redraft.resolved(child, {tree.root.id}),
  ]);
}

final class _Redraft {
  _Redraft(NoteTree tree, this._replaced)
    : _around = {
        for (final id in _replaced.keys)
          ...?tree.placeOf(id)?.path.map((container) => container.id),
      };

  final Map<BlockId, List<Draft>> _replaced;

  /// The containers a replaced block is in.
  final Set<BlockId> _around;

  /// The drafts [block] becomes, where the entries of [taken] were taken.
  List<Draft> draftsOf(Block block, Set<BlockId> taken) =>
      switch (_replaced[block.id]) {
        final drafts? when !taken.contains(block.id) => [
          for (final draft in drafts) ...resolved(draft, {...taken, block.id}),
        ],
        _ => _keptOrAnew(block, taken),
      };

  List<Draft> _keptOrAnew(Block block, Set<BlockId> taken) => switch (block) {
    final ContainerBlock container when _around.contains(block.id) =>
      _withChildren(asDraft(container), [
        for (final child in container.children) ...draftsOf(child, taken),
      ]),
    _ => [KeptDraft(block)],
  };

  List<Draft> resolved(Draft draft, Set<BlockId> taken) => switch (draft) {
    KeptDraft(:final block) => draftsOf(block, taken),
    QuoteDraft(:final children) || ItemDraft(:final children) => _withChildren(
      draft,
      [for (final child in children) ...resolved(child, taken)],
    ),
    ListDraft(:final items) => _withChildren(draft, [
      for (final item in items) ...resolved(item, taken),
    ]),
    _ => [draft],
  };
}

/// [draft], a container's, with [children] instead; none for a list
/// left without items.
List<Draft> _withChildren(Draft draft, List<Draft> children) => switch (draft) {
  QuoteDraft(:final id, :final from) => [QuoteDraft(id, children, from: from)],
  ItemDraft(:final id, :final checked, :final from) => [
    ItemDraft(id, children, checked: checked, from: from),
  ],
  ListDraft() when children.isEmpty => const [],
  ListDraft(
    :final id,
    :final kind,
    :final loose,
    :final numbering,
    :final start,
    :final from,
  ) =>
    [
      ListDraft(
        id,
        children,
        kind: kind,
        loose: loose,
        numbering: numbering,
        start: start,
        from: from,
      ),
    ],
  _ => throw ArgumentError.value(draft, 'draft', 'no container'),
};
