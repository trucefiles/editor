import '../doc/doc_tree.dart';
import '../summary/document_summary.dart';
import 'reload.dart';

/// The text an editor owner starts with, read once: Markdown edit shows
/// the [text] as it is, the other modes its doc tree; before the owner
/// starts, it tells whether the text [hasCheckboxes] and its [summary].
final class MarkdownStart {
  MarkdownStart.read(this.text) : document = loaded(text);

  final String text;

  /// The text read as a document.
  final Loaded document;

  DocTree get _doc => document.doc;

  /// Whether it has a checklist item anywhere.
  bool get hasCheckboxes => _doc.hasCheckboxes;

  /// What lists show of the text.
  late final DocumentSummary summary = DocumentSummary.ofTree(
    _doc,
    maxLines: 0,
  );
}
