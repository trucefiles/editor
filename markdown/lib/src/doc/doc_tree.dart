import 'doc_nodes.dart';

/// Hands out ids no node of a document has yet, in order.
final class FreshIds {
  FreshIds(this._next);

  int _next;

  /// The first id not handed out yet.
  int get next => _next;

  NodeId take() => NodeId(_next++);
}

/// Where a node is: the container it is in (`null` for the root) and its
/// index there.
typedef NodePlace = ({DocBlock node, DocContainer? parent, int index});

/// A document tree: its [root], and the first id no node of it or of the
/// trees it was changed from has. Immutable; questions are lookups,
/// derived once per tree when first asked.
final class DocTree {
  DocTree(this.root, {required this.nextId});

  final DocRoot root;

  /// The first id no node has.
  final int nextId;

  /// Ids for new nodes of an edit of this tree.
  FreshIds get freshIds => FreshIds(nextId);

  late final Map<NodeId, NodePlace> _places = () {
    final places = <NodeId, NodePlace>{};
    void walk(DocBlock node, DocContainer? parent, int index) {
      places[node.id] = (node: node, parent: parent, index: index);
      if (node is DocContainer) {
        final children = node.children;
        for (var child = 0; child < children.length; child++) {
          walk(children[child], node, child);
        }
      }
    }

    walk(root, null, 0);
    return places;
  }();

  /// The node [id] and where it is; `null` if there is none.
  NodePlace? placeOf(NodeId id) => _places[id];

  /// The node [id]; `null` if there is none.
  DocBlock? nodeOf(NodeId id) => _places[id]?.node;

  /// The container node [id] is in; `null` for the root or no node.
  DocContainer? parentOf(NodeId id) => _places[id]?.parent;

  /// The containers node [id] is in, the root first.
  List<DocContainer> pathOf(NodeId id) {
    final path = <DocContainer>[];
    for (
      var parent = parentOf(id);
      parent != null;
      parent = parentOf(parent.id)
    ) {
      path.add(parent);
    }
    return path.reversed.toList();
  }

  /// This tree with node [id] replaced by [nodes] in its container; the
  /// first id no node has is [fresh]'s next if given.
  DocTree replaced(NodeId id, List<DocBlock> nodes, {FreshIds? fresh}) {
    final place = _places[id]!;
    final parent = place.parent;
    if (parent == null) {
      assert(nodes.length == 1 && nodes.single is DocRoot, 'a root stays');
      return DocTree(nodes.single as DocRoot, nextId: fresh?.next ?? nextId);
    }
    DocContainer changed = parent.withChildren([
      ...parent.children.take(place.index),
      ...nodes,
      ...parent.children.skip(place.index + 1),
    ]);
    for (
      var inner = _places[parent.id]!;
      inner.parent != null;
      inner = _places[inner.parent!.id]!
    ) {
      final outer = inner.parent!;
      changed = outer.withChildren([
        ...outer.children.take(inner.index),
        changed,
        ...outer.children.skip(inner.index + 1),
      ]);
    }
    return DocTree(changed as DocRoot, nextId: fresh?.next ?? nextId);
  }

  /// This tree with node [id] replaced by [node].
  DocTree withNode(DocBlock node, {FreshIds? fresh}) =>
      replaced(node.id, [node], fresh: fresh);

  /// This tree with each node that [replacements] has an entry for
  /// replaced by the entry's nodes (none: it goes), at any depth; the
  /// entries' nodes are taken as given. The root's entry, if any, is its
  /// children. The first id no node has is [fresh]'s next if given.
  DocTree edited(Map<NodeId, List<DocBlock>> replacements, {FreshIds? fresh}) {
    final around = {
      for (final id in replacements.keys) ...pathOf(id).map((node) => node.id),
    };
    final changed = switch (replacements[root.id]) {
      final children? => root.withChildren(children),
      null => editedIn(root, replacements, within: around).single,
    };
    return DocTree(changed as DocRoot, nextId: fresh?.next ?? nextId);
  }
}

/// [node] as [replacements] change it (see [DocTree.edited]): the nodes
/// it becomes. Only containers [within] are walked into, if given.
List<DocBlock> editedIn(
  DocBlock node,
  Map<NodeId, List<DocBlock>> replacements, {
  Set<NodeId>? within,
}) {
  if (replacements[node.id] case final nodes?) return nodes;
  if (node is! DocContainer || !(within?.contains(node.id) ?? true)) {
    return [node];
  }
  final children = [
    for (final child in node.children)
      ...editedIn(child, replacements, within: within),
  ];
  final same =
      children.length == node.children.length &&
      Iterable<int>.generate(children.length)
          .every((index) => identical(children[index], node.children[index]));
  return [if (same) node else node.withChildren(children)];
}
