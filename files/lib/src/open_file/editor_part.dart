import 'dart:async';

import 'package:truce_core/truce_core.dart';

import '../listed_file.dart';
import '../view_settings.dart';

/// Where an open file's editor starts: the [text] it opens with (read
/// as [version], `null` for a new file), what its type keeps of how it
/// shows on this device ([view]), whether it opens [readOnly], and whether
/// it is [isNew].
typedef EditorStart = ({
  String text,
  Version? version,
  ViewSettings view,
  bool readOnly,
  bool isNew,
});

/// What the file page gives an editor part.
final class EditorPage {
  const EditorPage({required this.keepView, required this.withFile});

  /// Changes what the type keeps of how the file shows on this
  /// device; for a new file, once it has a file.
  final void Function(ViewSettings Function(ViewSettings) change) keepView;

  /// Runs an action on the file, created first for a new
  /// file. If there is none, the action doesn't run and the page
  /// tells the user why.
  final Future<void> Function(FutureOr<void> Function(ListedFile file) action)
  withFile;
}

/// The part of the one file page that differs per file
/// type, without its looks: its editor, behind the page's way into it
/// ([editor]), and what the type keeps of how the file shows.
abstract interface class EditorPart {
  /// The page's way into the editor owner.
  PageEditor get editor;

  /// Shows the file only to read while [readOnly] (it can't be
  /// edited here now), else as the user picked.
  void showReadOnly({required bool readOnly});

  /// Whether the editor shows the text to edit (undo and redo work), not
  /// only to read.
  bool get isEditing;

  /// What the type keeps of how the file shows changed to [view].
  void viewChanged(ViewSettings view);

  /// Fires when the page shows the part differently (e.g. another mode
  /// picked).
  Stream<void> get changes;

  /// The page is gone; its editor is closed with the page's session.
  void dispose();
}
