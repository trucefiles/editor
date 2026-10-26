import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/clipboard/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/commands/links.dart';
import 'package:truce_markdown/src/edit/keys/key_map.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';
import 'package:truce_markdown/src/edit/shown/typing_style.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../../spec/spec_examples.dart';
import '../../support/document_corpus.dart';

void main() {
  final documents = [
    ...documentCorpus,
    for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
      for (final example in specExamples(spec)) example.markdown,
  ];

  test('random user actions keep the document and the selection sound', () {
    for (final (index, text) in documents.indexed) {
      final random = Random(index + 1000 * _seed);
      var document = ShownDocument(
        DocumentTree.read(text),
        done: random.nextBool() ? DoneSections() : null,
      );
      final steps = <String>[];
      for (var step = 0; step < 16; step++) {
        final command = _randomCommand(random, document);
        if (command == null) continue;
        steps.add(_describe(command));
        try {
          final edited = run(document, command);
          _expectSound(edited.document, edited.selection);
          document = edited.document;
        } on Object catch (error, trace) {
          if (Platform.environment['FUZZ_ALL'] != null) {
            print('FAIL document $index: ${'$error'.split('\n').first}');
            break;
          }
          fail(
            'from:\n${document.tree.text}\n---\nshowing:\n${_rows(document)}\n---\n'
            'after ${steps.join(', ')}\n'
            'seed $_seed, document $index\n$error\n$trace',
          );
        }
      }
    }
  });
}

final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

/// The document reads as a whole read of its text would, and [selection]
/// is on what it shows.
void _expectSound(ShownDocument document, Selection selection) {
  final reread = ShownDocument(DocumentTree.read(document.tree.text));
  expect(
    [for (final leaf in document.tree.leaves) leaf.runtimeType],
    [for (final leaf in reread.tree.leaves) leaf.runtimeType],
    reason: 'reads as a whole read would',
  );
  switch (selection) {
    case TextSelection(:final base, :final extent):
      for (final place in [base, extent]) {
        expect(document.rowOf(place.slot), isNotNull, reason: '$place shows');
        expect(
          place.offset,
          inInclusiveRange(0, document.textOf(place.slot).length),
          reason: '$place is in its text',
        );
      }
    case BlockSelection(:final block):
      expect(document.blockRowOf(block), isNotNull, reason: '$block shows');
  }
}

const _words = ['a', 'b c', '*', ' ', 'www.x.io', '`', '# ', '- ', '1.', r'\'];

Command? _randomCommand(Random random, ShownDocument document) {
  final texts = [
    for (final row in document.rows)
      if (row case TextRow(:final slot)) (slot: slot, done: row.done),
  ];
  final items = [
    for (final leaf in document.tree.leaves)
      if (document.tree.parentOf(leaf) case final ItemBlock item) item,
  ];
  if (texts.isEmpty) return null;
  Place place(({Slot slot, bool done}) text) =>
      Place(text.slot, random.nextInt(document.textOf(text.slot).length + 1));
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
    0 || 1 || 2 => InsertText(
      caret.base,
      pick(_words),
      typingStyleAt(document, caret.base),
    ),
    3 when !range.isCaret => ReplaceText(
      first == second ? range : caret,
      pick(_words),
    ),
    4 => Paste(
      range,
      random.nextBool()
          ? plainLines('x\ny', Formatting.plain)
          : copiedLines(document, range),
    ),
    5 when items.isNotEmpty => switch (random.nextInt(4)) {
      0 => Toggle(pick(items).id, caret),
      1 => DeleteItem(pick(items).id),
      2 => AddItem(document.tree.parentOf(pick(items))!.id),
      _ => _move(random, document, items, caret),
    },
    6 => SetHeading(caret.base, pick([null, 1, 2, 3])),
    7 => ToggleStyle(range, pick(TextFormat.values)),
    8 => switch (random.nextBool()) {
      true when canRemoveLink(document, caret.base) => RemoveLink(caret.base),
      _ when first == second => SetLink(range, pick(['', 'site']), 'u'),
      _ => null,
    },
    9 => random.nextBool() ? ClearChecked(caret) : MoveToEnd(caret),
    _ => switch (keyAction(document, range, pick(EditKey.values))) {
      RunCommand(:final command) => command,
      _ => null,
    },
  };
}

Command? _move(
  Random random,
  ShownDocument document,
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
  JoinWithPrevious(:final slot) => 'JoinWithPrevious($slot)',
  JoinWithNext(:final slot) => 'JoinWithNext($slot)',
  RemoveFrame(:final slot) => 'RemoveFrame($slot)',
  LeaveList(:final slot) => 'LeaveList($slot)',
  RemoveLink(:final at) => 'RemoveLink($at)',
  Toggle(:final item) => 'Toggle($item)',
  DeleteItem(:final item) => 'DeleteItem($item)',
  AddItem(:final list) => 'AddItem($list)',
  _ => command.runtimeType.toString(),
};

/// What [document] shows, row by row.
String _rows(ShownDocument document) => [
  for (final row in document.rows)
    switch (row) {
      TextRow(:final slot, :final done) =>
        '$slot${done ? ' done' : ''}: "${document.textOf(slot).text}"',
      BlockRow(:final leaf) => '${leaf.runtimeType}',
    },
].join('\n');
