import 'text_change.dart';
import 'undoable_edit.dart';

/// An edit of a text kept as its [change] alone: where it was, what went
/// and what came. Undo and redo apply it to the text that shows, which
/// must be the text the edit left, or made it from.
final class TextStep implements UndoableEdit<TextStep> {
  const TextStep(this.change);

  final TextChange change;

  /// [text], the text the edit left, with the edit taken back, and the
  /// caret right after the text put back.
  ({String text, int caret}) undoneIn(String text) =>
      _swapped(text, change.added, change.removed);

  /// [text], the text the edit was made on, with the edit made again, and
  /// the caret right after the text it added.
  ({String text, int caret}) redoneIn(String text) =>
      _swapped(text, change.removed, change.added);

  @override
  TextStep joined(TextStep next) => TextStep(followedBy(change, next.change));

  /// [text] with [out], at the change's start, replaced by [into]. Any
  /// other text there is a bug: the step is not of this text.
  ({String text, int caret}) _swapped(String text, String out, String into) {
    final (start, end) = (change.start, change.start + out.length);
    if (end > text.length || text.substring(start, end) != out) {
      throw StateError('an undo step applied to a text it is not of');
    }
    return (
      text: text.replaceRange(start, end, into),
      caret: start + into.length,
    );
  }
}
