import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/format_state.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import 'support/shown.dart';

/// What is on in [text] from offset [from] to [to] of row [row].
FormatState _at(String text, int from, [int? to, int row = 0]) {
  final document = Shown.read(text);
  return formatStateAt(
    document.view,
    TextSelection(document.place(row, from), document.place(row, to ?? from)),
  );
}

void main() {
  test('at a caret, the formats typing there takes', () {
    expect(_at('a **b** c', 3).formats, {TextFormat.strong});
    expect(_at('a **b** c', 1).formats, isEmpty);
    expect(_at('***b***', 1).formats, {TextFormat.strong, TextFormat.emphasis});
  });

  test('at a caret, the style the user set there first', () {
    final document = Shown.read('a b');
    final state = formatStateAt(
      document.view,
      document.caret(0, 1),
      typingStyle: Formatting({TextFormat.emphasis}),
    );
    expect(state.formats, {TextFormat.emphasis});
  });

  test('over a selection, the formats every character has', () {
    expect(_at('**ab** c', 0, 2).formats, {TextFormat.strong});
    expect(_at('**ab** c', 0, 3).formats, isEmpty);
  });

  test('over no text, only a line break, no format is on', () {
    final document = Shown.read('a\n\nb');
    final state = formatStateAt(
      document.view,
      TextSelection(document.place(0, 1), document.place(1, 0)),
    );
    expect(state.formats, isEmpty);
  });

  test('in a link, and at its end', () {
    expect(_at('a [link](https://x.io) b', 3).link, isTrue);
    expect(_at('a [link](https://x.io) b', 6).link, isTrue);
    expect(_at('a [link](https://x.io) b', 1).link, isFalse);
  });

  test("the caret's block", () {
    expect(_at('- [ ] a', 0).blocks, {BlockKind.checklist});
    expect(_at('- a', 0).blocks, {BlockKind.bullets});
    expect(_at('1. a', 0).blocks, {BlockKind.numbers});
    expect(_at('# a', 0).blocks, {BlockKind.heading});
    expect(_at('> - a', 0).blocks, {BlockKind.quote, BlockKind.bullets});
    expect(_at('a', 0).blocks, isEmpty);
  });

  test('a subitem counts by its own list', () {
    expect(_at('1. a\n   - [ ] b', 0, null, 1).blocks, {BlockKind.checklist});
  });

  test('nothing is on without a caret, or at a divider', () {
    final document = Shown.read('a\n\n---');
    expect(formatStateAt(document.view, null), FormatState.none);
    expect(
      formatStateAt(document.view, BlockCaret(document.leaf(1))),
      FormatState.none,
    );
  });
}
