import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import '../folders/document_folder.dart';
import 'document_card_summary.dart';
import 'document_settings.dart';

/// One document file, as last read.
@immutable
final class Document {
  Document({
    required this.folder,
    required this.path,
    required this.type,
    required this.file,
    required this.version,
    required this.modified,
  });

  /// The folder it shows in, found from its path.
  final DocumentFolder folder;

  /// Where it is in [folder]'s base folder.
  final RelPath path;

  final DocumentType type;
  final TextFile file;

  /// Version on disk that [file] was read from or written as.
  final FileVersion version;

  /// When the file was last changed, for sorting.
  final DateTime modified;

  DocumentKey get key => (baseId: folder.base.id, path: path);

  /// Worked out once, on first use, from [file], by its type.
  late final DocumentCardSummary _summary = type.cardSummary(file.text, path);

  String get title => _summary.title;

  /// The preview of the document's text for its card, as its [settings]
  /// on this device say; see [DocumentCardSummary].
  String preview(DocumentSettings settings) => _summary.preview(settings);

  /// This document shown in [folder], with its current name and color;
  /// itself if that is unchanged.
  Document inFolder(DocumentFolder folder) => folder == this.folder
      ? this
      : Document(
          folder: folder,
          path: path,
          type: type,
          file: file,
          version: version,
          modified: modified,
        );
}

/// Identifies a document across rescans and folder changes: its base
/// folder, by id, and its path there.
typedef DocumentKey = ({String baseId, RelPath path});
