import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart' show TextEdit;

/// A text to show in a line editor, and where its caret goes (`null`: it
/// stays where it is).
typedef ShownText = ({String text, int? caret});

/// What a line editor edits: one text, its lines broken by `\n`; each
/// change comes as an edit of the text that shows. Listeners hear of each
/// change of [shown].
abstract interface class EditedText implements Listenable {
  /// The text to show; `null` while the document shows no text to edit
  /// (e.g. in another mode).
  ShownText? get shown;

  /// The user made [edit] on the text that shows; [pasted] if by a paste,
  /// which is an undo step of its own.
  void edit(TextEdit edit, {required bool pasted});

  /// The user moved the caret: typing next is an undo step of its own.
  void caretMoved();
}
