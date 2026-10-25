import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart'
    show Edited, Picked, Replaced, SecureReason, Version;
import 'package:truce_markdown/truce_markdown.dart';

import '../support/document_corpus.dart';

/// Random user inputs, settle timers and changes from the file owner on
/// an editor owner; after each, the file owner has the text it shows,
/// the tree reads as a whole read would, and the selection shows.
void main() {
  test('random inputs keep the file owner in step and the state sound', () {
    for (var seed = 0; seed < 20; seed++) {
      for (final (index, text) in documentCorpus.indexed) {
        final random = Random(seed * 1000 + index);
        final owner = editorOwner(
          text,
          version: const Version(0),
          checkedItems: CheckedItems.values[random.nextInt(3)],
        );
        var fileText = text;
        var versions = 0;
        owner.outputs.listen((output) {
          if (output case ToFile(input: Edited(:final text))) fileText = text;
        });
        void fromFile(String text) {
          fileText = text;
          final version = Version(++versions);
          owner.send(
            FromFile(
              random.nextBool()
                  ? Replaced(text, version: version, ackRev: owner.state.rev)
                  : Picked(text, version: version),
            ),
          );
        }

        final steps = <String>[];
        for (var step = 0; step < 30; step++) {
          final input = _randomInput(random, owner.state);
          steps.add('$input');
          try {
            if (input == null) {
              fromFile('${owner.state.document.tree.text}\nz');
            } else {
              owner.send(input);
            }
            _expectSound(owner.state, fileText);
          } on Object catch (error) {
            fail(
              'seed $seed, document $index: $error\n'
              'after ${steps.join(', ')}\n${owner.state.document.tree.text}',
            );
          }
        }
      }
    }
  });
}

void _expectSound(EditorState state, String fileText) {
  final tree = state.document.tree;
  expect(tree.text, fileText, reason: 'the file owner has what shows');
  final reread = DocumentTree.read(tree.text);
  expect(
    [for (final leaf in tree.root.leaves) leaf.runtimeType],
    [for (final leaf in reread.root.leaves) leaf.runtimeType],
    reason: 'reads as a whole read would',
  );
  if (state.mode != EditMode.visual) return;
  switch (state.selection) {
    case TextSelection(:final base, :final extent):
      for (final place in [base, extent]) {
        expect(
          state.document.rowOf(place.slot),
          isNotNull,
          reason: '$place shows',
        );
        expect(
          place.offset,
          inInclusiveRange(0, state.document.textOf(place.slot).length),
        );
      }
    case BlockSelection(:final block):
      expect(state.document.blockRowOf(block), isNotNull);
  }
}

/// A random input on [state]; `null` for a change from the file owner.
EditorInput? _randomInput(Random random, EditorState state) {
  final document = state.document;
  final revision = state.revision;
  final texts = [
    for (final row in document.rows)
      if (row case TextRow(:final slot)) slot,
  ];
  final items = [
    for (final leaf in document.tree.root.leaves)
      if (document.tree.parentOf(leaf) case final ItemBlock item
          when item.checked != null)
        item.id,
  ];
  if (state.raw != null) {
    return random.nextBool()
        ? EditRaw(
            '<p>\nraw ${random.nextInt(9)}',
            base: 0,
            extent: 0,
            revision: revision,
          )
        : CaretMoved(
            TextSelection.caret(Place(texts.first, 0)),
            revision: revision,
          );
  }
  return switch (random.nextInt(12)) {
    0 || 1 when state.mode == EditMode.visual => Typed(
      ['a', ' ', 'b c', '*'][random.nextInt(4)],
      revision: revision,
    ),
    2 || 3 when state.mode == EditMode.visual => Pressed(
      EditKey.values[random.nextInt(EditKey.values.length)],
      revision: revision,
    ),
    4 when state.mode == EditMode.visual && texts.isNotEmpty => () {
      final slot = texts[random.nextInt(texts.length)];
      return CaretMoved(
        TextSelection.caret(
          Place(slot, random.nextInt(document.textOf(slot).length + 1)),
        ),
        revision: revision,
      );
    }(),
    5 when state.mode == EditMode.visual && items.isNotEmpty => ToggleItem(
      items[random.nextInt(items.length)],
      revision: revision,
    ),
    6 when state.holds.timer != null => SettleTimerFired(state.holds.timer!),
    7 => null,
    8 => SetMode(
      state.mode == EditMode.visual ? EditMode.markdown : EditMode.visual,
    ),
    9 when state.mode == EditMode.markdown => () {
      final lines = document.tree.lines.length;
      final start = random.nextInt(lines);
      return EditLines(
        LineChange(start, start + random.nextInt(min(2, lines - start) + 1), [
          (id: null, text: ['- [ ] x', '', '> q', 'text'][random.nextInt(4)]),
        ]),
        revision: revision,
      );
    }(),
    10 => SetCheckedItems(CheckedItems.values[random.nextInt(3)]),
    11 => SecureEditor(SecureReason.values[random.nextInt(3)]),
    _ => SetMode(EditMode.visual),
  };
}
