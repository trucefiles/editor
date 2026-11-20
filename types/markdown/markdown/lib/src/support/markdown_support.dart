import 'package:truce_core/truce_core.dart';

/// Markdown documents and checklists.
const markdownType = FileType('markdown');

/// What the app knows of Markdown files: `.md`.
final class MarkdownSupport implements FileTypeSupport {
  const MarkdownSupport();

  @override
  FileType get type => markdownType;

  @override
  Set<String> get extensions => const {'md'};
}
