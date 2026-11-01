import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'document.dart';
import 'document_card_summary.dart';

/// A document's file as the app last read or wrote it: the [document], its
/// [file] in its byte style, and its [text]. For a type that merges, the
/// text is the file merged with its conflict copies ([copies]); else the
/// file's own. Also what lists show of it ([summary]). Held only while the
/// document is open, compared, restored, or its card or search hit is
/// worked out. Never changes.
final class DocumentText {
  /// The text of [file], with no copies merged in.
  DocumentText(this.document, this.file) : text = file.text, copies = const [];

  /// [file] merged with [copies] into [text].
  DocumentText.merged(
    this.document,
    this.file, {
    required this.copies,
    required this.text,
  });

  final Document document;

  /// The main file as read or written; its text is its own, without the
  /// copies.
  final TextFile file;

  /// What the document reads.
  final String text;

  /// The conflict copies of the file read with it, in the order merged.
  final List<CopyRead> copies;

  /// The [copies] whose text is in [text]: settled when it is written.
  List<ConflictCopy> get mergedCopies => [
    for (final read in copies)
      if (read.merged) read.copy,
  ];

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

/// A conflict [copy] of a document's file, read with it: [merged] if its
/// text is in the document's, else it waits for the user (it could not
/// be read or merged).
final class CopyRead {
  const CopyRead(this.copy, {required this.merged});

  final ConflictCopy copy;
  final bool merged;
}
