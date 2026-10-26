/// What Markdown can write of a document tree.
library;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/origin.dart';
import '../tree/blocks.dart';
import 'text_layouts.dart';

/// [doc] as Markdown can write it, which is what a print of it reads
/// back as: texts as their layouts make them (see `layoutOf`), no empty
/// paragraphs or blank raw blocks, code in an item without spaces on its
/// blank lines, and two lists of a kind that meet as one list, unless
/// they were read so. Nodes as read ([origin]) stay as
/// they are; the others stay the same objects where nothing changes.
DocTree writableOf(DocTree doc, Origin origin, TextLayouts layouts) {
  final root = _Writable(origin, layouts).container(doc.root, inItem: false);
  return identical(root, doc.root)
      ? doc
      : DocTree(root as DocRoot, nextId: doc.nextId);
}

/// Whether [paragraph] writes nothing: it is empty, unless read so (a
/// paragraph of an empty link) as [origin] says.
bool writesNothing(ParagraphNode paragraph, Origin origin) =>
    paragraph.text.isEmpty &&
    !(origin.isLoaded(paragraph) && paragraph.source != null);

final class _Writable {
  _Writable(this._origin, this._layouts);

  final Origin _origin;
  final TextLayouts _layouts;

  DocBlock? block(DocBlock node, {required bool inItem}) => switch (node) {
    ParagraphNode() when writesNothing(node, _origin) => null,
    final CodeNode code when inItem => _blankLinesEmpty(code),
    _ when _origin.isLoaded(node) => node,
    final TextNode text => switch (_layouts.writable(text)) {
      ParagraphNode(:final text) when text.isEmpty => null,
      final writable => writable,
    },
    RawLeaf(:final raw) when raw.trim().isEmpty => null,
    DocLeaf() => node,
    DocContainer() => container(node, inItem: inItem),
  };

  DocContainer container(DocContainer node, {required bool inItem}) {
    if (_origin.isLoaded(node)) return node;
    final children = _merged([
      for (final child in node.children)
        ?block(child, inItem: inItem || node is ItemNode),
    ]);
    final same =
        children.length == node.children.length &&
        Iterable<int>.generate(children.length)
            .every((index) => identical(children[index], node.children[index]));
    return same ? node : node.withChildren(children);
  }

  /// [code] with its blank lines empty: an item's blank line holds no
  /// spaces.
  CodeNode _blankLinesEmpty(CodeNode code) {
    final emptied = code.code.replaceAll(_spacesOnlyLine, '');
    return emptied == code.code ? code : code.withCode(emptied);
  }

  /// [children] with each two lists of a kind that meet as one, unless
  /// they were read as two.
  List<DocBlock> _merged(List<DocBlock> children) =>
      children.fold([], (merged, child) {
        final last = merged.isEmpty ? null : merged.last;
        if (last is ListNode &&
            child is ListNode &&
            last.kind == child.kind &&
            !_readApart(last, child)) {
          merged.last = last.withChildren([...last.items, ...child.items]);
        } else {
          merged.add(child);
        }
        return merged;
      });

  /// Whether [a] and [b] were read as two lists of their kind, one right
  /// after the other: their markers keep them apart.
  bool _readApart(ListNode a, ListNode b) => switch ((a.source, b.source)) {
    (final ListBlock first, final ListBlock second) =>
      first.kind == a.kind &&
          second.kind == b.kind &&
          _origin.areNeighbors(first, second),
    _ => false,
  };
}

final _spacesOnlyLine = RegExp(r'^[ \t]+$', multiLine: true);
