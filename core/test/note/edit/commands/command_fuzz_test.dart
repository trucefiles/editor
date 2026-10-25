import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/commands/links.dart';
import 'package:truce_core/src/note/edit/keys/key_map.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/slot.dart';
import 'package:truce_core/src/note/edit/shown/typing_style.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

import '../../spec/spec_examples.dart';
import '../../support/note_corpus.dart';

void main() {
  final notes = [
    ...noteCorpus,
    for (final example in specExamples('gfm-0.29-extensions.txt'))
      example.markdown,
  ];

  test('random user actions keep the note and the selection sound', () {
    for (final (index, text) in notes.indexed) {
      final random = Random(index + 1000 * _seed);
      var note = ShownNote(
        NoteTree.read(text),
        done: random.nextBool() ? DoneSections() : null,
      );
      final steps = <String>[];
      for (var step = 0; step < 16; step++) {
        final command = _randomCommand(random, note);
        if (command == null) continue;
        steps.add(_describe(command));
        try {
          final edited = run(note, command);
          _expectSound(edited.note, edited.selection);
          note = edited.note;
        } on Object catch (error, trace) {
          if (Platform.environment['FUZZ_ALL'] != null) {
            print('FAIL note $index: ${'$error'.split('\n').first}');
            break;
          }
          fail(
            'from:\n${note.tree.text}\n---\nafter ${steps.join(', ')}\n'
            'seed $_seed, note $index\n$error\n$trace',
          );
        }
      }
    }
  });
}

final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

/// The note reads as a whole read of its text would, and [selection]
/// is on what it shows.
void _expectSound(ShownNote note, Selection selection) {
  final reread = ShownNote(NoteTree.read(note.tree.text));
  expect(
    [for (final leaf in note.tree.leaves) leaf.runtimeType],
    [for (final leaf in reread.tree.leaves) leaf.runtimeType],
    reason: 'reads as a whole read would',
  );
  switch (selection) {
    case TextSelection(:final base, :final extent):
      for (final place in [base, extent]) {
        expect(note.rowOf(place.slot), isNotNull, reason: '$place shows');
        expect(
          place.offset,
          inInclusiveRange(0, note.textOf(place.slot).length),
          reason: '$place is in its text',
        );
      }
    case BlockSelection(:final block):
      expect(note.blockRowOf(block), isNotNull, reason: '$block shows');
  }
}

const _words = ['a', 'b c', '*', ' ', 'www.x.io', '`', '# ', '- ', '1.', r'\'];

Command? _randomCommand(Random random, ShownNote note) {
  final texts = [
    for (final row in note.rows)
      if (row case TextRow(:final slot)) (slot: slot, done: row.done),
  ];
  final items = [
    for (final leaf in note.tree.leaves)
      if (note.tree.parentOf(leaf) case final ItemBlock item) item,
  ];
  if (texts.isEmpty) return null;
  Place place(({Slot slot, bool done}) text) =>
      Place(text.slot, random.nextInt(note.textOf(text.slot).length + 1));
  final first = texts[random.nextInt(texts.length)];
  final second = random.nextInt(3) == 0
      ? texts
            .where((text) => text.done == first.done)
            .elementAt(
              random.nextInt(texts.where((t) => t.done == first.done).length),
            )
      : first;
  final range = TextSelection(place(first), place(second));
  final caret = TextSelection.caret(range.base);
  T pick<T>(List<T> from) => from[random.nextInt(from.length)];
  return switch (random.nextInt(12)) {
    0 ||
    1 ||
    2 => InsertText(caret.base, pick(_words), typingStyleAt(note, caret.base)),
    3 when !range.isCaret => ReplaceText(
      first == second ? range : caret,
      pick(_words),
    ),
    4 => Paste(range, 'x\ny', Formatting.plain),
    5 when items.isNotEmpty => switch (random.nextInt(4)) {
      0 => Toggle(pick(items).id, caret),
      1 => DeleteItem(pick(items).id),
      2 => AddItem(note.tree.parentOf(pick(items))!.id),
      _ => _move(random, note, items, caret),
    },
    6 => SetHeading(caret.base, pick([null, 1, 2, 3])),
    7 => ToggleStyle(range, pick(TextFormat.values)),
    8 => switch (random.nextBool()) {
      true when canRemoveLink(note, caret.base) => RemoveLink(caret.base),
      _ when first == second => SetLink(range, pick(['', 'site']), 'u'),
      _ => null,
    },
    9 => random.nextBool() ? ClearChecked(caret) : MoveToEnd(caret),
    _ => switch (keyAction(note, range, pick(EditKey.values))) {
      RunCommand(:final command) => command,
      _ => null,
    },
  };
}

Command? _move(
  Random random,
  ShownNote note,
  List<ItemBlock> items,
  Selection selection,
) {
  final item = items[random.nextInt(items.length)];
  final targets = items
      .where((target) => !idsIn(item).contains(target.id))
      .toList();
  if (targets.isEmpty) return null;
  return MoveItem(
    item.id,
    targets[random.nextInt(targets.length)].id,
    below: random.nextBool(),
    selection: selection,
  );
}

String _describe(Command command) => switch (command) {
  InsertText(:final at, :final text) => 'InsertText($at, "$text")',
  ReplaceText(:final range, :final text) => 'ReplaceText($range, "$text")',
  DeleteRange(:final range) => 'DeleteRange($range)',
  LineBreak(:final range) => 'LineBreak($range)',
  SplitBlock(:final range) => 'SplitBlock($range)',
  Paste(:final range) => 'Paste($range)',
  ToggleStyle(:final selection, :final format) =>
    'ToggleStyle($selection, ${format.name})',
  SetLink(:final range, :final text) => 'SetLink($range, "$text")',
  SetHeading(:final at, :final level) => 'SetHeading($at, $level)',
  SetFrame(:final selection, :final kind) =>
    'SetFrame($selection, ${kind.name})',
  Indent(:final selection) => 'Indent($selection)',
  Outdent(:final selection) => 'Outdent($selection)',
  MoveItem(:final item, :final target, :final below) =>
    'MoveItem($item, $target, below: $below)',
  _ => command.runtimeType.toString(),
};
