import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'markdown_editor_part.dart';
import 'markdown_editor_view.dart';
import 'markdown_services.dart';

/// Markdown documents, edited in Visual edit, Markdown edit or Read.
final class MarkdownEditableType extends MarkdownFileType
    implements EditableType {
  const MarkdownEditableType(this.services);

  final MarkdownServices services;

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = MarkdownEditorPart(start, page);
    return (part: part, view: MarkdownEditorView(part, services));
  }
}
