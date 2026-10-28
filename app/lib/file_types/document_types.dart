import 'package:truce_core/truce_core.dart';

import 'document_type.dart';
import 'markdown_document_type.dart';
import 'plain_text_document_type.dart';

/// The document types the app handles: the one place that picks them,
/// at compile time.
final documentTypes = DocumentTypes(const [
  MarkdownDocumentType(),
  PlainTextDocumentType(),
]);

/// The type new documents are created in.
const newDocumentType = MarkdownDocumentType();

/// The document types the app handles, and which one a file is.
final class DocumentTypes {
  DocumentTypes(List<DocumentType> types)
    : detector = ExtensionFileTypeDetector.of([
        for (final type in types) type.support,
      ]),
      _byId = {for (final type in types) type.support.type: type};

  /// Tells which handled type a file is; the files of no handled type
  /// are not shown.
  final FileTypeDetector detector;

  final Map<FileType, DocumentType> _byId;

  /// The type of the file at [path], a file of a handled type.
  DocumentType of(RelPath path) => switch (detector.detect(path)) {
    final type? => _byId[type]!,
    null => throw ArgumentError.value(path, 'path', 'not of a handled type'),
  };
}
