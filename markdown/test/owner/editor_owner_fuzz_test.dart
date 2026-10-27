import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart'
    show Edited, Picked, Replaced, SecureReason, Version;
import 'package:truce_markdown/truce_markdown.dart';

import '../support/document_corpus.dart';

/// Random user inputs, save timers and changes from the file owner on an
/// editor owner; after each, the selection shows, and once nothing is
/// unsent, the file owner has the text Markdown edit would show.
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
        var rev = 0;
        final timers = <int>[];
        var versions = 0;
        owner.outputs.listen((output) {
          switch (output) {
            case ToFile(input: Edited(:final text, rev: final edited)):
              fileText = text;
              rev = edited;
            case StartSaveTimer(:final id):
              timers.add(id);
            case _:
          }
        });
        void fromFile(String text) {
          fileText = text;
          final version = Version(++versions);
          owner.send(
            FromFile(
              random.nextBool()
                  ? Replaced(text, version: version, ackRev: rev)
                  : Picked(text, version: version, rev: rev),
            ),
          );
        }

        final steps = <String>[];
        for (var step = 0; step < 30; step++) {
          final input = _randomInput(random, owner.state, timers);
          steps.add('$input');
          try {
            switch (input) {
              case null when !owner.state.unsent:
                fromFile('$fileText\n\nz');
              case null:
                break;
              case final input:
                owner.send(input);
            }
            _expectSound(owner.state, fileText);
          } on Object catch (error) {
            fail(
              'seed $seed, document $index: $error\n'
              'after ${steps.join(', ')}\nfrom: $text',
            );
          }
        }
      }
    }
  });
}

void _expectSound(EditorState state, String fileText) {
  switch (state.content) {
    case MarkdownContent(:final text) when !state.unsent:
      expect(text, fileText, reason: 'the file owner has what shows');
    case MarkdownContent():
      break;
    case FormattedContent(:final view, :final selection):
      switch (selection) {
        case TextSelection(:final base, :final extent):
          for (final place in [base, extent]) {
            final row = view.row(place.leaf);
            expect(row, isA<TextRow>(), reason: '$place shows');
            expect(place.offset, inInclusiveRange(0, textOf(row!.leaf).length));
          }
        case BlockSelection(:final block):
          expect(view.row(block), isA<BlockRow>(), reason: '$block shows');
      }
  }
}

/// A random input on [state], [timers] the save timers started so far;
/// `null` for a change from the file owner.
EditorInput? _randomInput(Random random, EditorState state, List<int> timers) {
  final revision = state.revision;
  T pick<T>(List<T> from) => from[random.nextInt(from.length)];
  final visual = switch (state.content) {
    final FormattedContent shown when state.mode == EditMode.visual => shown,
    _ => null,
  };
  final texts = [...?visual?.view.rows.whereType<TextRow>()];
  final items = [
    if (visual != null)
      for (final node in nodesIn(visual.view.doc.root))
        if (node case ItemNode(checked: _?, :final id)) id,
  ];
  final raws = [
    ...?visual?.view.rows.whereType<BlockRow>().where(
      (row) => row.leaf is RawLeaf,
    ),
  ];
  final markdown = switch (state.content) {
    MarkdownContent(:final text) => text,
    FormattedContent() => null,
  };
  // Any input may come while a raw block is open; it closes first.
  if (visual?.raw != null && random.nextBool()) {
    return EditRaw(
      pick(['<p>', '# raw', '']),
      base: 0,
      extent: 0,
      revision: revision,
    );
  }
  final over = switch (visual?.selection) {
    final TextSelection selection => selection,
    _ => null,
  };
  return switch (random.nextInt(16)) {
    0 || 1 when over != null => Typed(
      pick(['a', ' ', 'b c', '*', 'x\ny']),
      over: over,
      revision: revision,
    ),
    2 ||
    3 when visual != null => Pressed(pick(EditKey.values), revision: revision),
    4 when texts.isNotEmpty => () {
      final row = pick(texts);
      return CaretMoved(
        TextSelection.caret(
          Place(row.leaf.id, random.nextInt(textOf(row.leaf).length + 1)),
        ),
        revision: revision,
      );
    }(),
    5 when items.isNotEmpty => ToggleItems([
      pick(items),
      if (random.nextBool()) pick(items),
    ], revision: revision),
    6 when timers.isNotEmpty => SaveTimerFired(pick(timers)),
    7 => null,
    8 => SetMode(pick(EditMode.values)),
    9 when markdown != null => EditText(
      '$markdown${pick(['\n- [ ] x', '\n', '\n> q', ' text'])}',
      revision: revision,
    ),
    10 => SetCheckedItems(pick(CheckedItems.values)),
    11 => SecureEditor(pick(SecureReason.values)),
    12 when raws.isNotEmpty => OpenRawBlock(
      pick(raws).leaf.id,
      atEnd: random.nextBool(),
      revision: revision,
    ),
    13 => Undo(revision: revision),
    14 => Redo(revision: revision),
    _ => SetMode(EditMode.visual),
  };
}
