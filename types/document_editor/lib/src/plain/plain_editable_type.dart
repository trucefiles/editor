import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import 'plain_editor_part.dart';
import 'plain_editor_view.dart';

/// Plain text documents, edited as text.
final class PlainTextEditableType extends PlainTextFileType
    implements EditableType {
  const PlainTextEditableType();

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = PlainEditorPart(start);
    return (part: part, view: PlainEditorView(part));
  }
}
