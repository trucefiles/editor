import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// Hands the library each batch of input method changes fixed for Visual
/// edit (see [fixedBatch]).
final class ImeBatchFix extends DeltaTextInputClientDecorator {
  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) =>
      super.updateEditingValueWithDeltas(fixedBatch(textEditingDeltas));
}

/// [deltas] up to and with the first new line; the rest are dropped, as
/// they count on the text the input method had before Visual edit
/// reshaped it for the new line (the library sends the input method the
/// text as it is right after). A change before the new line that comes
/// after it (Samsung's keyboard sends its autocorrect after the new line)
/// is moved ahead of it, so it isn't lost.
List<TextEditingDelta> fixedBatch(List<TextEditingDelta> deltas) {
  final newline = deltas.indexWhere(_isNewline);
  if (newline < 0) return deltas;
  final line = deltas[newline];
  final at = switch (line) {
    TextEditingDeltaInsertion(:final insertionOffset) => insertionOffset,
    _ => null,
  };
  final ahead = at == null
      ? const <TextEditingDelta>[]
      : deltas.skip(newline + 1).takeWhile((delta) => _endsBefore(delta, at));
  if (ahead.isEmpty) return deltas.sublist(0, newline + 1);
  final moved = ahead.fold((text: line.oldText, deltas: <TextEditingDelta>[]), (
    done,
    delta,
  ) {
    final rebased = _onText(delta, done.text);
    return (
      text: rebased.apply(_valueOf(done.text)).text,
      deltas: [...done.deltas, rebased],
    );
  });
  final shift = moved.text.length - line.oldText.length;
  final offset = at! + shift;
  return [
    ...deltas.sublist(0, newline),
    ...moved.deltas,
    TextEditingDeltaInsertion(
      oldText: moved.text,
      textInserted: '\n',
      insertionOffset: offset,
      selection: TextSelection.collapsed(offset: offset + 1),
      composing: TextRange.empty,
    ),
  ];
}

bool _isNewline(TextEditingDelta delta) => switch (delta) {
  TextEditingDeltaInsertion(textInserted: '\n') => true,
  TextEditingDeltaReplacement(replacementText: '\n') => true,
  _ => false,
};

/// Whether [delta] changes only text before [offset].
bool _endsBefore(TextEditingDelta delta, int offset) => switch (delta) {
  TextEditingDeltaReplacement(:final replacedRange) =>
    replacedRange.end <= offset,
  TextEditingDeltaDeletion(:final deletedRange) => deletedRange.end <= offset,
  _ => false,
};

/// [delta], which changes text before the new line, as a change of
/// [text], the text before the new line came.
TextEditingDelta _onText(TextEditingDelta delta, String text) =>
    switch (delta) {
      TextEditingDeltaReplacement(
        :final replacedRange,
        :final replacementText,
      ) =>
        TextEditingDeltaReplacement(
          oldText: text,
          replacementText: replacementText,
          replacedRange: replacedRange,
          selection: TextSelection.collapsed(
            offset: replacedRange.start + replacementText.length,
          ),
          composing: TextRange.empty,
        ),
      TextEditingDeltaDeletion(:final deletedRange) => TextEditingDeltaDeletion(
        oldText: text,
        deletedRange: deletedRange,
        selection: TextSelection.collapsed(offset: deletedRange.start),
        composing: TextRange.empty,
      ),
      _ => delta,
    };

TextEditingValue _valueOf(String text) => TextEditingValue(text: text);
