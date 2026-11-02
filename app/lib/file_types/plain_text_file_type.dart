import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import 'editable_type.dart';

/// Plain text documents: the first line names one; edited as text.
final class PlainTextFileType implements EditableType {
  const PlainTextFileType();

  @override
  PlainTextSupport get support => const PlainTextSupport();

  @override
  String get name => 'Plain text';

  @override
  String get newFileExtension => '.txt';

  @override
  TextFile get newFile => const TextFile.empty();

  /// The whole text.
  @override
  String searchText(FileText read) => read.text;

  @override
  FileCardSummary cardSummary(FileText read) {
    final preview = read.summary.preview(const PlainPreview());
    return FileCardSummary(
      title: titleOf(read.summary, read.path),
      preview: (_) => preview,
    );
  }

  /// Texts are compared and picked by the user.
  @override
  TextMerge? get merge => null;

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = PlainEditorPart(start);
    return (part: part, view: PlainEditorView(part));
  }
}
