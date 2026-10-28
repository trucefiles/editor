import 'package:truce_core/truce_core.dart';

import '../summary/document_summary.dart';

/// Markdown documents and checklists.
const markdownType = FileType('markdown');

/// What the app knows of Markdown files: `.md`, and what lists show of
/// one ([DocumentSummary]).
final class MarkdownSupport implements FileTypeSupport<MarkdownPreview> {
  const MarkdownSupport();

  @override
  FileType get type => markdownType;

  @override
  Set<String> get extensions => const {'md'};

  @override
  DocumentSummary summary(String text, {required int maxLines}) =>
      DocumentSummary.of(text, maxLines: maxLines);
}
