import 'package:flutter/foundation.dart';

/// A text to show in a line editor, and where its caret goes (`null`: it
/// stays where it is).
typedef ShownText = ({String text, int? caret});

/// What a line editor edits: one text, sent whole after each change.
/// Listeners hear of each change of [shown].
abstract interface class EditedText implements Listenable {
  /// The text to show; `null` while the document shows no text to edit
  /// (e.g. in another mode).
  ShownText? get shown;

  /// The user changed the text to [text]; [pasted] if by a paste, which
  /// is an undo step of its own.
  void edit(String text, {required bool pasted});

  /// The user moved the caret: typing next is an undo step of its own.
  void caretMoved();
}
