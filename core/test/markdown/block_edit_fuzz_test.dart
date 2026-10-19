import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Seeded random edit sequences through the block mapping, as an editor
/// showing the arranged document would make them: untouched lines stay
/// byte-identical and in order, nothing is lost or duplicated.
void main() {
  const cases = 400;
  const steps = 25;
  const lineKinds = [
    '- [ ] open',
    '- [x] done',
    '  - [ ] sub',
    '    * [X] deep',
    '\t+ [ ] tab',
    '- [ ]tight',
    '# Heading **bold**',
    'plain text  ',
    '    indented text',
    '',
    '1. [ ] numbered',
    '- not a box',
    '* bullet',
    '  2) numbered sub',
    '---',
    '| a | b |',
    '|---|---|',
  ];
  const texts = ['x', '', ' lead', 'trail ', '**b**', '[ ] box', '- [ ] y'];

  test('untouched lines keep their bytes and order', () {
    final random = Random(11);
    for (var c = 0; c < cases; c++) {
      var doc = MarkdownLines.parse(
        [
          for (var i = random.nextInt(12) + 1; i > 0; i--)
            lineKinds[random.nextInt(lineKinds.length)],
        ].join('\n'),
      );
      for (var s = 0; s < steps; s++) {
        final arrangement = Arrangement(
          doneSection: random.nextBool(),
          collapsed: random.nextBool()
              ? {for (final list in doc.lists) list.first.id}
              : const {},
        );
        final shown = [
          for (final entry in arrangement.of(doc))
            if (entry is LineEntry) entry.id,
        ];
        final step = _Step.random(random, doc, shown, texts);
        final (next, added) = doc.applyEdits(step.edits, shown: shown.toSet());
        step.check(doc, next, added);
        doc = next;
      }
    }
  });
}

/// One random editor transaction on the shown lines.
final class _Step {
  _Step(this.edits, this.changed, this.removed, this.addedBlocks);

  factory _Step.random(
    Random random,
    MarkdownLines doc,
    List<LineId> shown,
    List<String> texts,
  ) {
    final byId = {for (final line in doc.lines) line.id: line};
    final edits = <BlockEdit>[];
    final changed = <LineId, Block>{};
    final removed = <LineId>{};
    final added = <Block>[];
    String text() => texts[random.nextInt(texts.length)];
    Block randomItem({ListKind? kind, int? depth, String? itemText}) {
      final itemKind =
          kind ?? ListKind.values[random.nextInt(ListKind.values.length)];
      return ItemBlock(
        kind: itemKind,
        checked: itemKind == ListKind.checkbox && random.nextBool(),
        depth: depth ?? random.nextInt(3),
        text: itemText ?? text(),
      );
    }

    Block randomBlock() => random.nextBool() ? randomItem() : TextBlock(text());
    for (final id in shown) {
      final line = byId[id]!;
      switch (random.nextInt(8)) {
        case 0 when !removed.contains(id):
          final block = doc.isItem(line) && random.nextBool()
              ? randomItem(
                  kind: random.nextInt(4) == 0 ? null : line.listKind,
                  depth: max(0, doc.depthOf(line) + random.nextInt(3) - 1),
                  itemText: random.nextBool() ? line.text : null,
                )
              : randomBlock();
          edits.add(BlockChanged(id, block));
          changed[id] = block;
        case 1 when shown.length - removed.length > 1:
          edits.add(BlockRemoved(id));
          removed.add(id);
        case 2:
          final blocks = [
            for (var n = random.nextInt(2) + 1; n > 0; n--) randomBlock(),
          ];
          final after = removed.contains(id) ? null : id;
          edits.add(BlocksAdded(blocks, after: after));
          added.addAll(blocks);
        default:
          break;
      }
    }
    return _Step(edits, changed, removed, added);
  }

  final List<BlockEdit> edits;
  final Map<LineId, Block> changed;
  final Set<LineId> removed;
  final List<Block> addedBlocks;

  void check(MarkdownLines before, MarkdownLines after, List<LineId> added) {
    final reason = 'before:\n${before.text}\nafter:\n${after.text}';
    final ids = [for (final line in after.lines) line.id];
    expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
    expect(added, hasLength(addedBlocks.length), reason: reason);
    expect(ids, containsAll(added), reason: reason);
    final untouched = [
      for (final line in before.lines)
        if (!changed.containsKey(line.id) && !removed.contains(line.id)) line,
    ];
    final afterById = {for (final line in after.lines) line.id: line};
    for (final line in untouched) {
      expect(afterById[line.id]?.raw, line.raw, reason: reason);
    }
    final order = [
      for (final line in after.lines)
        if (untouched.any((u) => u.id == line.id)) line.id,
    ];
    expect(order, [for (final line in untouched) line.id], reason: reason);
    for (final id in removed) {
      expect(afterById, isNot(contains(id)), reason: reason);
    }
    for (final MapEntry(key: id, value: block) in changed.entries) {
      final line = afterById[id]!;
      switch (block) {
        case TextBlock(:final text):
          expect(line.raw, MarkdownLine.oneLine(text), reason: reason);
        case ItemBlock(:final kind, :final checked, :final depth, :final text):
          // The text can make it another kind, e.g. a bullet with `[ ] `.
          var expected = MarkdownLine.newItem(line.id, kind, text);
          if (checked) expected = expected.toggled();
          expect(line.listKind, expected.listKind, reason: reason);
          expect(line.isChecked, expected.isChecked, reason: reason);
          expect(line.text, expected.text, reason: reason);
          expect(after.depthOf(line), depth, reason: reason);
      }
    }
    expect(
      before.lines.length - removed.length + added.length,
      after.lines.length,
      reason: reason,
    );
  }
}
