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
      _shown(text, reversedChange(change));

  /// [text], the text the edit was made on, with the edit made again, and
  /// the caret right after the text it added.
  ({String text, int caret}) redoneIn(String text) => _shown(text, change);

  @override
  TextStep joined(TextStep next) => TextStep(followedBy(change, next.change));

  static ({String text, int caret}) _shown(String text, TextChange change) => (
    text: applyChange(text, change),
    caret: change.start + change.added.length,
  );
}
