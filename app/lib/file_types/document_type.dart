import 'package:truce_core/truce_core.dart';

import '../document_page/editor_part.dart';
import '../documents/document_card_summary.dart';

/// What one document type brings the app: its files ([support]), what
/// cards show of a text, and its part of the one text document page.
abstract interface class DocumentType {
  FileTypeSupport<Object?> get support;

  /// What cards and search show of [text], the content of the file at
  /// [path].
  DocumentCardSummary cardSummary(String text, RelPath path);

  /// The editor part of an open document of this type, starting at
  /// [start], on [page].
  EditorPart editorPart(EditorStart start, EditorPage page);
}
