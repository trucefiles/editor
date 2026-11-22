import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import 'editor_view.dart';

/// A file type with how the app shows its files: the type's pure side,
/// its icon, and which page a file of it opens on. Each type's UI
/// package brings its types; the app lists them. One case per page: the
/// text editing page ([EditableType]) or the view page ([ViewType]).
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

/// A file type whose files open on the view page: looked at, not
/// edited (e.g. pictures). The page around it is the app's (name,
/// place, actions); the type draws what a file holds.
abstract interface class ViewType implements FilePageType {
  /// [content] shown whole, to look at closely (e.g. zoomed): on the
  /// file's page and as a side of a comparison. [label] is read out.
  /// It fills the space it is given. On the file's page that is the
  /// whole page, so it sits in the middle of the screen; the page's bar,
  /// banners and place go over its top, as far as its top padding
  /// ([MediaQuery.paddingOf]) says.
  Widget view(ShownContent content, {required String label});

  /// [content] small, as a card shows it, filling the space it gets.
  Widget thumbnail(ShownContent content, {required String label});

  /// Asks the user for a new file of [kind] (e.g. a picture to choose or
  /// take); `null` if they made none. [hint] tells the user something
  /// short (e.g. that a file can't be used).
  Future<NewContent?> makeNew(
    BuildContext context,
    NewFileKind kind, {
    required void Function(String message) hint,
  });
}

/// The content of one version of a file, read once by [read] when it
/// shows; contents with equal [id]s are the same, so what was drawn of
/// one is drawn again (e.g. a file key with its version).
final class ShownContent {
  const ShownContent(this.id, this.read);

  final Object id;

  /// `null` if it can't be read.
  final Future<Uint8List?> Function() read;
}

/// A new file the user made, to keep as it is: its [bytes] and the
/// file [name] it asks for, with its extension (a number is added if
/// it is taken).
typedef NewContent = ({Uint8List bytes, String name});
