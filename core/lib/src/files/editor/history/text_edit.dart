import 'text_change.dart';

/// A text after an edit, and the [change] that made it of the text
/// before: the edit says where it was, so no one has to find it again.
final class TextEdit {
  /// [before] with [change] made in it (see [applyChange]).
  TextEdit(String before, this.change) : text = applyChange(before, change);

  /// The text after the edit.
  final String text;

  /// What the edit changed in the text before.
  final TextChange change;

  /// Whether the text after differs from the text before.
  bool get changes => change.removed != change.added;
}
