import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart';

/// A session on the Markdown document [opened] (`null` for a new one),
/// whose file [effects] reads and writes, its editor in [mode].
DocumentSession markdownSession(
  DocumentText? opened,
  FileEffects effects, {
  EditMode mode = EditMode.visual,
}) => DocumentSession(
  opened,
  effects,
  MarkdownPageEditor(
    EditorGate(
      editorOwner(
        MarkdownStart.read(opened?.text ?? ''),
        version: opened?.seen.version,
        mode: mode,
      ),
    ),
  ),
);

extension MarkdownSession on DocumentSession {
  /// The way into the session's Markdown editor owner.
  EditorGate get gate => (editor as MarkdownPageEditor).gate;
}
