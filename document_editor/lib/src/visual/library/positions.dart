import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../row_looks.dart';
import 'library_nodes.dart';
import 'node_ids.dart';

/// Where a selection is, in the library's document and in the editor
/// owner's terms: the one mapping, both ways. Text positions are the
/// same offsets in both. A block selected whole is, for the library, a
/// caret at its end: a soft keyboard sees one character before the caret
/// and no range, so it can't move the caret off the block before it
/// deletes (keyboards first collapse a range to its end). A divider
/// selected as a range by the library is a block selection; an end on
/// any other node without text goes on past it, the way it moved, to the
/// nearest text there.
final class Positions {
  const Positions(this._document, this._ids);

  final Document _document;
  final NodeIds _ids;

  /// [selection] in the owner's terms, moved from [was]; `null` where no
  /// text is near.
  md.Selection? toOwner(DocumentSelection selection, {DocumentSelection? was}) {
    final DocumentSelection(:base, :extent) = selection;
    if (base.nodeId == extent.nodeId) {
      if (_lookAt(base.nodeId)
          case BlockLook(leaf: final md.DividerNode divider)
          when base.nodePosition != extent.nodePosition) {
        return md.BlockSelection(divider.id);
      }
    }
    return switch ((
      placeOf(base, was: was?.base),
      placeOf(extent, was: was?.extent),
    )) {
      (final base?, final extent?) => md.TextSelection(base, extent),
      _ => null,
    };
  }

  /// [position] as a text place: on a node without text, the nearest one
  /// past it, coming from [was]; `null` if there is none.
  md.Place? placeOf(DocumentPosition position, {DocumentPosition? was}) {
    final node = _document.getNodeById(position.nodeId);
    if (node == null) return null;
    return switch (lookOf(node)) {
      TextLook(:final leaf) => switch (position.nodePosition) {
        TextNodePosition(:final offset) => md.Place(leaf.id, offset),
        _ => null,
      },
      _ when _cameFromAbove(position, was) =>
        _nearest(node, before: false) ?? _nearest(node, before: true),
      _ => _nearest(node, before: true) ?? _nearest(node, before: false),
    };
  }

  /// Whether a move to [position] came from above it: from a node before
  /// it, or, from the node itself or nowhere, onto its end.
  bool _cameFromAbove(DocumentPosition position, DocumentPosition? was) {
    final from = switch (was) {
      final was? => _document.getNodeIndexById(was.nodeId),
      null => -1,
    };
    final to = _document.getNodeIndexById(position.nodeId);
    return from >= 0 && from != to
        ? from < to
        : position.nodePosition !=
              const UpstreamDownstreamNodePosition.upstream();
  }

  /// The end of the nearest text before [node], or the start of the
  /// nearest after it.
  md.Place? _nearest(DocumentNode node, {required bool before}) {
    final nodes = _document.toList();
    final index = nodes.indexOf(node);
    final side = before
        ? nodes.sublist(0, index).reversed
        : nodes.sublist(index + 1);
    return side
        .map(lookOf)
        .whereType<TextLook>()
        .map(
          (look) =>
              md.Place(look.leaf.id, before ? md.textOf(look.leaf).length : 0),
        )
        .firstOrNull;
  }

  /// The owner's [selection] in the library's document; `null` where a
  /// row it is in doesn't show. In an open [raw] block, its own caret.
  DocumentSelection? toLibrary(md.Selection selection, {md.RawRegion? raw}) {
    if (raw != null) {
      return switch (_ids.find(RawTextLook.keyOf(raw.block))) {
        final id? => DocumentSelection(
          base: _textPosition(id, raw.base),
          extent: _textPosition(id, raw.extent),
        ),
        null => null,
      };
    }
    return switch (selection) {
      md.TextSelection(:final base, :final extent) => switch ((
        positionOf(base),
        positionOf(extent),
      )) {
        (final base?, final extent?) => DocumentSelection(
          base: base,
          extent: extent,
        ),
        _ => null,
      },
      md.BlockSelection(:final block) => switch (_shown(block)) {
        final id? => DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: id,
            nodePosition: const UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
        null => null,
      },
    };
  }

  /// [place] in the library's document; `null` if its row doesn't show.
  DocumentPosition? positionOf(md.Place place) => switch (_shown(place.leaf)) {
    final id? => _textPosition(id, place.offset),
    null => null,
  };

  /// The node [leaf] shows in; every row that shows has one.
  String? _shown(md.NodeId leaf) => _ids.find(leaf);

  RowLook? _lookAt(String id) => switch (_document.getNodeById(id)) {
    final node? => lookOf(node),
    null => null,
  };

  static DocumentPosition _textPosition(String id, int offset) =>
      DocumentPosition(
        nodeId: id,
        nodePosition: TextNodePosition(offset: offset),
      );
}
