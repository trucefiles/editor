import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'editable_type.dart';

/// Markdown documents and checklists: cards leave checked items out
/// where the document shows them apart; edited in Visual edit, Markdown
/// edit or Read.
final class MarkdownDocumentType implements EditableType {
  const MarkdownDocumentType();

  @override
  MarkdownSupport get support => const MarkdownSupport();

  @override
  String get newFileExtension => '.md';

  @override
  DocumentCardSummary cardSummary(DocumentText read) {
    final summary = read.summary;
    final all = summary.preview(const MarkdownPreview(hideChecked: false));
    final open = summary.preview(const MarkdownPreview(hideChecked: true));
    return DocumentCardSummary(
      title: titleOf(summary, read.path),
      preview: (view) => switch (MarkdownView.of(view).checkedItems) {
        CheckedItems.inPlace => all,
        CheckedItems.doneSection || CheckedItems.moveToEnd => open,
      },
    );
  }

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = MarkdownEditorPart(start, page);
    return (part: part, view: MarkdownEditorView(part));
  }
}
