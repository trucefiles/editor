import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../documents/document_types.dart';
import 'editable_type.dart';
import 'markdown_document_type.dart';
import 'plain_text_document_type.dart';

/// The document types the app handles: the one place that picks them,
/// at compile time; handed down from here to whatever needs them, down to
/// what the app may touch in a folder.
final documentTypesProvider = Provider<DocumentTypes<EditableType>>(
  (_) => DocumentTypes(const [
    MarkdownDocumentType(),
    PlainTextDocumentType(),
  ], forNew: const MarkdownDocumentType()),
);
