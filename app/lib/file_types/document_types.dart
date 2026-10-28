import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import 'document_type.dart';
import 'markdown_document_type.dart';
import 'plain_text_document_type.dart';

/// The document types the app handles: the one place that picks them,
/// at compile time; handed down from here to whatever needs them, down to
/// what the app may touch in a folder.
final documentTypesProvider = Provider<DocumentTypes>(
  (_) => DocumentTypes(const [
    MarkdownDocumentType(),
    PlainTextDocumentType(),
  ], forNew: const MarkdownDocumentType()),
);

/// The document types the app handles, and which one a file is.
final class DocumentTypes {
  DocumentTypes(List<DocumentType> types, {required this.forNew})
    : detector = ExtensionFileTypeDetector.of([
        for (final type in types) type.support,
      ]),
      _byId = {for (final type in types) type.support.type: type};

  /// Tells which handled type a file is; the files of no handled type
  /// are not shown.
  final FileTypeDetector detector;

  /// The type new documents are created in.
  final DocumentType forNew;

  final Map<FileType, DocumentType> _byId;

  /// The type of the file at [path]; `null` if the app doesn't handle it,
  /// e.g. a path kept from an older app version.
  DocumentType? of(RelPath path) => switch (detector.detect(path)) {
    final type? => _byId[type],
    null => null,
  };

  /// Whether the app handles the file at [path].
  bool handles(RelPath path) => of(path) != null;
}
