import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/visual/library/ime_batches.dart';

TextEditingDeltaInsertion _insert(String old, String text, int at) =>
    TextEditingDeltaInsertion(
      oldText: old,
      textInserted: text,
      insertionOffset: at,
      selection: TextSelection.collapsed(offset: at + text.length),
      composing: TextRange.empty,
    );

TextEditingDeltaReplacement _replace(
  String old,
  String text,
  int from,
  int to,
) => TextEditingDeltaReplacement(
  oldText: old,
  replacementText: text,
  replacedRange: TextRange(start: from, end: to),
  selection: TextSelection.collapsed(offset: from + text.length),
  composing: TextRange.empty,
);

/// The text after [deltas], applied in order from their first old text.
String _applied(List<TextEditingDelta> deltas) =>
    deltas.fold(TextEditingValue(text: deltas.first.oldText), (value, delta) {
      return delta.apply(value);
    }).text;

void main() {
  test('a batch without a new line stays as it is', () {
    final batch = [_insert('ab', 'c', 2), _insert('abc', 'd', 3)];

    expect(fixedBatch(batch), batch);
  });

  test('changes after the new line are dropped (Gboard)', () {
    final batch = [
      _insert('ab', 'c', 2),
      _insert('abc', '\n', 3),
      _insert('abc\n', 'x', 4),
    ];

    expect(fixedBatch(batch), batch.sublist(0, 2));
  });

  test('an autocorrect sent after the new line goes before it (Samsung)', () {
    final batch = [_insert('teh', '\n', 3), _replace('teh\n', 'the', 0, 3)];

    final fixed = fixedBatch(batch);

    expect(_applied(fixed), 'the\n');
    expect(fixed.last, isA<TextEditingDeltaInsertion>());
    expect((fixed.last as TextEditingDeltaInsertion).textInserted, '\n');
  });

  test('a longer autocorrect moves the new line along', () {
    final batch = [_insert('im', '\n', 2), _replace('im\n', "I'm", 0, 2)];

    final fixed = fixedBatch(batch);

    expect(_applied(fixed), "I'm\n");
    expect((fixed.last as TextEditingDeltaInsertion).insertionOffset, 3);
  });
}
