import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../document_page/editor_part.dart';
import '../documents/document_card_summary.dart';
import '../documents/document_title.dart';
import '../editor/markdown/markdown_editor_part.dart';
import '../editor/markdown/markdown_view.dart';
import 'document_type.dart';

/// Markdown documents and checklists: cards leave checked items out
/// where the document shows them apart; edited in Visual edit, Markdown
/// edit or Read.
final class MarkdownDocumentType implements DocumentType {
  const MarkdownDocumentType();

  @override
  MarkdownSupport get support => const MarkdownSupport();

  @override
  String get newFileExtension => '.md';

  @override
  DocumentCardSummary cardSummary(String text, RelPath path) {
    final summary = support.summary(
      text,
      maxLines: DocumentCardSummary.previewLines,
    );
    final all = summary.preview(const MarkdownPreview(hideChecked: false));
    final open = summary.preview(const MarkdownPreview(hideChecked: true));
    return DocumentCardSummary(
      title: titleOf(summary, path),
      preview: (view) => switch (MarkdownView.of(view).checkedItems) {
        CheckedItems.inPlace => all,
        CheckedItems.doneSection || CheckedItems.moveToEnd => open,
      },
    );
  }

  @override
  EditorPart editorPart(EditorStart start, EditorPage page) =>
      MarkdownEditorPart(start, page);
}
