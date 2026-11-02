import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart';

/// A session on the Markdown document [opened] (`null` for a new one),
/// whose file [effects] reads and writes, its editor in [mode]; [merge]
/// as a type that merges would give it.
FileSession markdownSession(
  FileText? opened,
  FileEffects effects, {
  EditMode mode = EditMode.visual,
  TextMerge? merge,
}) => FileSession(
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
  merge: merge,
);

extension MarkdownSession on FileSession {
  /// The way into the session's Markdown editor owner.
  EditorGate get gate => (editor as MarkdownPageEditor).gate;
}
