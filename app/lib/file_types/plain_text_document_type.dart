import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import 'editable_type.dart';

/// Plain text documents: the first line names one; edited as text.
final class PlainTextDocumentType implements EditableType {
  const PlainTextDocumentType();

  @override
  PlainTextSupport get support => const PlainTextSupport();

  @override
  String get newFileExtension => '.txt';

  @override
  DocumentCardSummary cardSummary(String text, RelPath path) {
    final summary = support.summary(
      text,
      maxLines: DocumentCardSummary.previewLines,
    );
    final preview = summary.preview(const PlainPreview());
    return DocumentCardSummary(
      title: titleOf(summary, path),
      preview: (_) => preview,
    );
  }

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = PlainEditorPart(start);
    return (part: part, view: PlainEditorView(part));
  }
}
