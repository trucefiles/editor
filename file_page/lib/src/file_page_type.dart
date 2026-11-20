import 'package:flutter/widgets.dart';
import 'package:truce_files/truce_files.dart';

import 'editor_view.dart';

/// A file type with how the app shows its files: the type's pure side,
/// its icon, and which page a file of it opens on. Each type's UI
/// package brings its types; the app lists them. One case per page:
/// today every type opens on the text editing page ([EditableType]).
sealed class FilePageType implements ShownFileType {
  /// The icon that tells a file of this type apart, e.g. on its card and
  /// its filter chip.
  IconData get icon;
}

/// A text file type with its editor on the text editing page: how a
/// file of it opens.
abstract interface class EditableType implements FilePageType, TextFileType {
  /// Opens the editor of a file of this type, starting at [start], on
  /// [page]: its part the page model drives, and the view the page shows
  /// of it.
  OpenedEditor openEditor(EditorStart start, EditorPage page);
}

/// An open file's editor: its [part] and the [view] of it.
typedef OpenedEditor = ({EditorPart part, EditorView view});
