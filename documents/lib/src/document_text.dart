import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'document.dart';
import 'document_card_summary.dart';

/// A document's file as the app last read or wrote it: the [document] and
/// its text, in its file's byte style ([file]), and what lists show of it
/// ([summary]). Held only while the document is open, compared, restored,
/// or its card or search hit is worked out. Never changes.
final class DocumentText {
  DocumentText(this.document, this.file);

  final Document document;
  final TextFile file;

  String get text => file.text;

  /// What cards and search show of [text], by its type; read when first
  /// asked, once for title and preview.
  late final TextSummary<Object?> summary = type.summary(
    text,
    maxLines: DocumentCardSummary.previewLines,
  );

  DocumentFolder get folder => document.folder;
  RelPath get path => document.path;
  FileTypeSupport<Object?> get type => document.type;
  DocumentKey get key => document.key;
}
