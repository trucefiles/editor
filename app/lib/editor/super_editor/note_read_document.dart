import 'dart:async';

import 'package:super_editor/super_editor.dart';

import '../note_document_controller.dart';
import '../note_mode.dart';
import 'marks/markup_text.dart';
import 'read_nodes.dart';
import 'sync_document.dart';

/// The [note] as a read-only super_editor [editor], formatted; shows each
/// change of [note], e.g. a folded "Done" section or a change from
/// elsewhere.
final class NoteReadDocument {
  NoteReadDocument(this.note) {
    editor = Editor(
      editables: {
        Editor.documentKey: MutableDocument(nodes: _nodes()),
        Editor.composerKey: MutableDocumentComposer(),
      },
      requestHandlers: defaultRequestHandlers.cast<EditRequestHandler>(),
    );
    note.addListener(_scheduleSync);
  }

  final NoteDocumentController note;
  late final Editor editor;
  bool _syncScheduled = false;
  bool _disposed = false;

  List<DocumentNode> _nodes() =>
      readNodes(note.entries, note.lines, mode: NoteMode.read);

  /// The url of the link at [position], as its text's attributions mark
  /// it.
  String? linkAt(DocumentPosition position) => switch ((
    editor.document.getNodeById(position.nodeId),
    position.nodePosition,
  )) {
    (final TextNode node, TextNodePosition(:final offset)) => attributedLinkAt(
      node.text,
      offset,
    ),
    _ => null,
  };

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    scheduleMicrotask(() {
      _syncScheduled = false;
      if (!_disposed) syncDocument(editor, _nodes());
    });
  }

  void dispose() {
    _disposed = true;
    note.removeListener(_scheduleSync);
    editor.dispose();
  }
}
