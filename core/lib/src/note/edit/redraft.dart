import '../note_tree.dart';
import '../tree/blocks.dart';
import '../write/block/block_writer.dart';
import '../write/draft.dart';

/// The draft of [tree]'s note with [replaced] blocks: each block with an
/// entry becomes its drafts (none to remove it), and the root's entry
/// is its children; containers with such a block in them are drafted
/// anew around it; all else is kept. A kept block among an entry's
/// drafts takes its own entry, except the very block the entry is for
/// (which a draft may wrap), and except one that removes it where the
/// drafts put it in another container: it moved there. So a block moves
/// by an entry that places it and one that removes it from where it was.
RootDraft redrafted(NoteTree tree, Map<BlockId, List<Draft>> replaced) {
  final redraft = _Redraft(tree, replaced);
  return RootDraft(tree.root, [
    ...switch (replaced[tree.root.id]) {
      final children? => [
        for (final child in children)
          ...redraft.resolved(child, {tree.root.id}, tree.root.id),
      ],
      null => [
        for (final child in tree.root.children)
          ...redraft.draftsOf(child, const {}),
      ],
    },
  ]);
}

final class _Redraft {
  _Redraft(this._tree, this._replaced)
    : _around = {
        for (final id in _replaced.keys)
          ...?_tree.placeOf(id)?.path.map((container) => container.id),
      };

  final NoteTree _tree;
  final Map<BlockId, List<Draft>> _replaced;

  /// The containers a replaced block is in.
  final Set<BlockId> _around;

  /// The drafts [block] becomes, where the entries of [taken] were taken.
  List<Draft> draftsOf(Block block, Set<BlockId> taken) =>
      switch (_replaced[block.id]) {
        final drafts? when !taken.contains(block.id) => [
          for (final draft in drafts)
            ...resolved(draft, {...taken, block.id}, _tree.parentOf(block)?.id),
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

  /// The drafts [draft] becomes in the container [parent].
  List<Draft> resolved(Draft draft, Set<BlockId> taken, BlockId? parent) =>
      switch (draft) {
        KeptDraft(:final block)
            when (_replaced[block.id]?.isEmpty ?? false) &&
                _tree.parentOf(block)?.id != parent =>
          _keptOrAnew(block, taken),
        KeptDraft(:final block) => draftsOf(block, taken),
        QuoteDraft(:final children) ||
        ItemDraft(:final children) => _withChildren(draft, [
          for (final child in children) ...resolved(child, taken, draft.id),
        ]),
        ListDraft(:final items) => _withChildren(draft, [
          for (final item in items) ...resolved(item, taken, draft.id),
        ]),
        _ => [draft],
      };
}

/// [draft], a container's, with [children] instead; none for a list
/// left without items or a quote left without blocks.
List<Draft> _withChildren(Draft draft, List<Draft> children) => switch (draft) {
  QuoteDraft(children: final before)
      when children.isEmpty && before.isNotEmpty =>
    const [],
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
