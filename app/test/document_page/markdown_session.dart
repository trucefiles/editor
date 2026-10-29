import 'package:truce_editor/document_page/document_session.dart';
import 'package:truce_editor/document_page/file_effects.dart';
import 'package:truce_editor/documents/document_text.dart';
import 'package:truce_editor/documents/document_version.dart';
import 'package:truce_editor/editor/editor_gate.dart';
import 'package:truce_editor/editor/markdown/markdown_page_editor.dart';
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
        opened?.text ?? '',
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
