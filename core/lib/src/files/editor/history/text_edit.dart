import 'text_change.dart';

/// A text after an edit, and the [change] that made it of the text
/// before: the edit says where it was, so no one has to find it again.
final class TextEdit {
  /// [before] with [change] made in it (see [applyChange]).
  TextEdit(this.before, this.change) : text = applyChange(before, change);

  /// The text the edit was made on.
  final String before;

  /// The text after the edit.
  final String text;

  /// What the edit changed in the text before.
  final TextChange change;

  /// Whether the text after differs from the text before.
  bool get changes => change.removed != change.added;

  /// Whether the edit was made on [text]; an editor sends edits of the
  /// very text it got, so this is an identity check.
  bool isOf(String text) => identical(before, text) || before == text;
}
