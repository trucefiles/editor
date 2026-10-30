import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart';

/// A session on the Markdown document [opened] (`null` for a new one),
/// whose file [effects] reads and writes, naming files from the
/// session's summaries; its editor in [mode].
DocumentSession markdownSession(
  DocumentText? opened,
  FileEffects Function(SentSummary summaries) effects, {
  EditMode mode = EditMode.visual,
}) {
  final start = MarkdownStart.read(opened?.text ?? '');
  final summaries = SentSummary(
    const MarkdownSupport(),
    text: start.text,
    summary: start.summary,
  );
  return DocumentSession(
    opened,
    effects(summaries),
    MarkdownPageEditor(
      EditorGate(editorOwner(start, version: opened?.seen.version, mode: mode)),
    ),
    summaries: summaries,
  );
}

/// The summaries of a Markdown document that opened with [text].
SentSummary markdownSummaries([String text = '']) => SentSummary(
  const MarkdownSupport(),
  text: text,
  summary: DocumentSummary.of(text, maxLines: 0),
);

extension MarkdownSession on DocumentSession {
  /// The way into the session's Markdown editor owner.
  EditorGate get gate => (editor as MarkdownPageEditor).gate;
}
