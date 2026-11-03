import 'package:flutter/widgets.dart';
import 'package:truce_files/truce_files.dart';

import 'editor_view.dart';

/// A file type with its editor on the one file page: the type's pure
/// side, and how a file of it opens. Each editor package brings its
/// types; the app lists them.
abstract interface class EditableType implements ShownFileType {
  /// The icon that tells a file of this type apart, e.g. on its card and
  /// its filter chip.
  IconData get icon;

  /// Opens the editor of a file of this type, starting at [start], on
  /// [page]: its part the page model drives, and the view the page shows
  /// of it.
  OpenedEditor openEditor(EditorStart start, EditorPage page);
}

/// An open file's editor: its [part] and the [view] of it.
typedef OpenedEditor = ({EditorPart part, EditorView view});
