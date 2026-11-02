import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'editable_type.dart';

/// Markdown documents and checklists: cards leave checked items out
/// where the file shows them apart; edited in Visual edit, Markdown
/// edit or Read.
final class MarkdownFileType implements EditableType {
  const MarkdownFileType();

  @override
  MarkdownSupport get support => const MarkdownSupport();

  @override
  String get newFileExtension => '.md';

  @override
  TextFile get newFile => const TextFile.empty();

  /// The whole text.
  @override
  String searchText(FileText read) => read.text;

  @override
  FileCardSummary cardSummary(FileText read) {
    final summary = read.summary;
    final all = summary.preview(const MarkdownPreview(hideChecked: false));
    final open = summary.preview(const MarkdownPreview(hideChecked: true));
    return FileCardSummary(
      title: titleOf(summary, read.path),
      preview: (view) => switch (MarkdownView.of(view).checkedItems) {
        CheckedItems.inPlace => all,
        CheckedItems.doneSection || CheckedItems.moveToEnd => open,
      },
    );
  }

  /// Texts are compared and picked by the user.
  @override
  TextMerge? get merge => null;

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = MarkdownEditorPart(start, page);
    return (part: part, view: MarkdownEditorView(part));
  }
}
