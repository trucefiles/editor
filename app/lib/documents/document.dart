import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';
import 'document_card_summary.dart';

/// One document file, as last read.
@immutable
final class Document {
  Document({
    required this.folder,
    required this.path,
    required this.file,
    required this.version,
    required this.modified,
  });

  final DocumentFolder folder;
  final RelPath path;
  final TextFile file;

  /// Version on disk that [file] was read from or written as.
  final FileVersion version;

  /// When the file was last changed, for sorting.
  final DateTime modified;

  DocumentKey get key => (folderId: folder.id, path: path);

  /// Worked out once, on first use, from [file].
  late final DocumentCardSummary _summary = DocumentCardSummary.of(
    file.text,
    path,
  );

  String get title => _summary.title;

  /// The preview of the document's text for its card; see [DocumentCardSummary].
  String preview({required bool hideDone}) =>
      _summary.previewOf(hideDone: hideDone);

  /// This document with [folder]'s current name and color; itself if they are
  /// unchanged.
  Document inFolder(DocumentFolder folder) => folder == this.folder
      ? this
      : Document(
          folder: folder,
          path: path,
          file: file,
          version: version,
          modified: modified,
        );
}

/// Identifies a document across rescans.
typedef DocumentKey = ({String folderId, RelPath path});
