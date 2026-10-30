import 'dart:async';

import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import 'plain_page_editor.dart';

/// A plain text document's part of the document page: its editor owner,
/// edited line by line as written, or only read while it can't be
/// edited. Keeps nothing of how the document shows.
final class PlainEditorPart implements EditorPart {
  PlainEditorPart(EditorStart start)
    : owner = plainOwner(start.text, version: start.version),
      _readOnly = start.readOnly;

  /// The editor owner.
  final PlainOwner owner;

  @override
  late final PageEditor editor = PlainPageEditor(owner);

  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get changes => _changes.stream;

  bool _readOnly;

  @override
  void showReadOnly({required bool readOnly}) {
    if (readOnly == _readOnly) return;
    _readOnly = readOnly;
    _changes.add(null);
  }

  @override
  bool get isEditing => !_readOnly;

  @override
  void viewChanged(ViewSettings view) {}

  @override
  void dispose() => unawaited(_changes.close());
}
