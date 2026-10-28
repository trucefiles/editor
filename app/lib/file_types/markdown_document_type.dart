import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../document_page/editor_part.dart';
import '../documents/document_card_summary.dart';
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
  DocumentCardSummary cardSummary(String text, RelPath path) => cardSummaryOf(
    support.summary(text, maxLines: DocumentCardSummary.previewLines),
    path,
    options: {
      for (final hideChecked in [false, true])
        hideChecked: MarkdownPreview(hideChecked: hideChecked),
    },
    optionOf: (view) =>
        MarkdownView.of(view).checkedItems != CheckedItems.inPlace,
  );

  @override
  EditorPart editorPart(EditorStart start, EditorPage page) =>
      MarkdownEditorPart(start, page);
}
