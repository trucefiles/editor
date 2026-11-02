import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

/// A file type as the app wires it: the type itself, and its editor
/// on the one file page.
abstract interface class EditableType implements ShownFileType {
  /// Opens the editor of a file of this type, starting at [start], on
  /// [page]: its part the page model drives, and the view the page shows
  /// of it.
  OpenedEditor openEditor(EditorStart start, EditorPage page);
}

/// An open file's editor: its [part] and the [view] of it.
typedef OpenedEditor = ({EditorPart part, EditorView view});
