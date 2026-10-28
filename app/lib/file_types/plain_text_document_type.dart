import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import '../document_page/editor_part.dart';
import '../documents/document_card_summary.dart';
import '../editor/plain/plain_editor_part.dart';
import 'document_type.dart';

/// Plain text documents: the first line names one; edited as text.
final class PlainTextDocumentType implements DocumentType {
  const PlainTextDocumentType();

  @override
  PlainTextSupport get support => const PlainTextSupport();

  @override
  String get newFileExtension => '.txt';

  @override
  DocumentCardSummary cardSummary(String text, RelPath path) => cardSummaryOf(
    support.summary(text, maxLines: DocumentCardSummary.previewLines),
    path,
    options: (_) => const PlainPreview(),
  );

  @override
  EditorPart editorPart(EditorStart start, EditorPage page) =>
      PlainEditorPart(start);
}
