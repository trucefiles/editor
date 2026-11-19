import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../owner/editor_contract.dart' show CheckedItems;
import '../summary/document_summary.dart';
import 'markdown_support.dart';
import 'markdown_view.dart';

/// Markdown documents and checklists, as the app shows them: cards
/// leave checked items out where the file shows them apart; search reads
/// the whole text; two texts don't merge (the user picks one). Its
/// editor package adds how a file of it opens.
base class MarkdownFileType implements ShownFileType {
  const MarkdownFileType();

  @override
  MarkdownSupport get support => const MarkdownSupport();

  @override
  String get name => 'Markdown';

  @override
  TextFile get newFile => const TextFile.empty();

  @override
  List<NewFileKind> get newKinds => const [NewFileKind('Document')];

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
}
