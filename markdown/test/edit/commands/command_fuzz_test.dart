import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/commands/links.dart';
import 'package:truce_markdown/src/edit/keys/key_map.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/edit/typing_style.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../../spec/spec_examples.dart';
import '../../support/document_corpus.dart';
import '../support/shown.dart';

void main() {
  final documents = [
    ...documentCorpus,
    for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
      for (final example in specExamples(spec)) example.markdown,
  ];

  test('random user actions keep the document and the selection sound', () {
    for (final (index, text) in documents.indexed) {
      final random = Random(index + 1000 * _seed);
      var document = Shown.read(
        text,
        done: random.nextBool() ? DoneSections() : null,
      );
      final steps = <String>[];
      for (var step = 0; step < 16; step++) {
        final command = _randomCommand(random, document);
        if (command == null) continue;
        steps.add(_describe(command));
        try {
          final edited = document.run(command);
          _expectShows(edited.document, edited.selection);
          document = edited.document;
        } on Object catch (error, trace) {
          if (Platform.environment['FUZZ_ALL'] != null) {
            print('FAIL document $index: ${'$error'.split('\n').first}');
            break;
          }
          fail(
            'from:\n${document.text}\n---\nshowing:\n${_rows(document)}\n'
            '---\nafter ${steps.join(', ')}\n'
            'seed $_seed, document $index\n$error\n$trace',
          );
        }
      }
    }
  });
}

final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

/// Expects [selection] on what [document] shows.
void _expectShows(Shown document, Selection selection) {
  switch (selection) {
    case TextSelection(:final base, :final extent):
      for (final place in [base, extent]) {
        final row = document.view.row(place.leaf);
        expect(row, isA<TextRow>(), reason: '$place shows');
        expect(
          place.offset,
          inInclusiveRange(0, textOf(row!.leaf).length),
          reason: '$place is in its text',
        );
      }
    case BlockSelection(:final block):
      expect(document.view.row(block), isA<BlockRow>(), reason: '$block');
  }
}

const _words = ['a', 'b c', '*', ' ', 'www.x.io', '`', '# ', '- ', '1.', r'\'];

// HTML left open (`<!--`) takes in what follows only once read again:
// see docs/known-limitations.md.
const _raws = ['<div>', '[x]: /u', '| a |\n|---|', 'text', ''];

Command? _randomCommand(Random random, Shown document) {
  final view = document.view;
  final texts = view.rows.whereType<TextRow>().toList();
  final raws = view.rows
      .whereType<BlockRow>()
      .where((row) => row.leaf is RawLeaf)
      .toList();
  final dividers = view.rows.where((row) => row.leaf is DividerNode).toList();
  final items = nodesIn(view.doc.root).whereType<ItemNode>().toList();
  if (texts.isEmpty) return null;
  T pick<T>(List<T> from) => from[random.nextInt(from.length)];
  Place place(TextRow row) =>
      Place(row.leaf.id, random.nextInt(textOf(row.leaf).length + 1));
  final first = pick(texts);
  final second = random.nextInt(3) == 0
      ? pick(texts.where((text) => text.done == first.done).toList())
      : first;
  final range = TextSelection(place(first), place(second));
  final caret = TextSelection.caret(range.base);
  return switch (random.nextInt(14)) {
    0 || 1 || 2 => InsertText(
      caret.base,
      pick(_words),
      typingStyleAt(view.doc, caret.base),
    ),
    3 when !range.isCaret => ReplaceText(
      first == second ? range : caret,
      pick(_words),
    ),
    4 => Paste(
      range,
      random.nextBool()
          ? plainLines('x\ny', Formatting.plain)
          : copiedLines(view, range),
    ),
    5 when items.isNotEmpty => switch (random.nextInt(4)) {
      0 => Toggle(pick(items).id, caret),
      1 => DeleteItem(pick(items).id),
      2 => AddItem(view.doc.parentOf(pick(items).id)!.id),
      _ => _move(random, items, caret),
    },
    6 => SetHeading(caret.base, pick([null, 1, 2, 3])),
    7 => ToggleStyle(range, pick(TextFormat.values)),
    8 => switch (random.nextBool()) {
      true when canRemoveLink(view, caret.base) => RemoveLink(caret.base),
      _ when first == second => SetLink(range, pick(['', 'site']), 'u'),
      _ => null,
    },
    9 => random.nextBool() ? ClearChecked(caret) : MoveToEnd(caret),
    10 when raws.isNotEmpty => CloseRaw(pick(raws).leaf.id, pick(_raws), caret),
    11 when dividers.isNotEmpty => RemoveBlock(pick(dividers).leaf.id),
    _ => switch (keyAction(view, range, pick(EditKey.values))) {
      RunCommand(:final command) => command,
      _ => null,
    },
  };
}

Command? _move(Random random, List<ItemNode> items, Selection selection) {
  final item = items[random.nextInt(items.length)];
  final inside = nodesIn(item).map((node) => node.id).toSet();
  final targets = items.where((target) => !inside.contains(target.id)).toList();
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
  JoinWithPrevious(:final at) => 'JoinWithPrevious($at)',
  JoinWithNext(:final at) => 'JoinWithNext($at)',
  RemoveFrame(:final leaf) => 'RemoveFrame($leaf)',
  RemoveLink(:final at) => 'RemoveLink($at)',
  Toggle(:final item) => 'Toggle($item)',
  DeleteItem(:final item) => 'DeleteItem($item)',
  AddItem(:final list) => 'AddItem($list)',
  CloseRaw(:final block, :final raw) => 'CloseRaw($block, "$raw")',
  _ => command.runtimeType.toString(),
};

/// What [document] shows, row by row.
String _rows(Shown document) => [
  for (final row in document.view.rows)
    switch (row) {
      TextRow(:final leaf, :final done) =>
        '${leaf.id}${done ? ' done' : ''}: "${textOf(leaf).text}"',
      BlockRow(:final leaf) => '${leaf.id} ${leaf.runtimeType}',
    },
].join('\n');
