import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Random documents and list actions: every action changes only the
/// lines it is about, and never loses text it does not remove.
void main() {
  const cases = 3000;
  const lineKinds = [
    '- [ ] open',
    '- [x] done',
    '  - [ ] sub',
    '    * [X] deep',
    '\t+ [ ] tab',
    '- [ ]tight',
    '# Heading',
    'plain text',
    '    indented text',
    '',
    '1. [ ] numbered',
    '- not a box',
    '* bullet',
    '  2) numbered sub',
    '---',
  ];

  late Random random;

  setUp(() => random = Random(7));

  MarkdownLines randomList() => MarkdownLines.parse(
    [
      for (var i = random.nextInt(10) + 1; i > 0; i--)
        lineKinds[random.nextInt(lineKinds.length)],
    ].join('\n'),
  );

  MarkdownLine? randomItem(MarkdownLines list) {
    final items = list.lines.where(list.isItem).toList();
    return items.isEmpty ? null : items[random.nextInt(items.length)];
  }

  List<String> raws(MarkdownLines list) => [for (final l in list.lines) l.raw];

  /// Whether [part] appears in [whole] in the same order.
  bool isSubsequence(List<String> part, List<String> whole) {
    var at = 0;
    for (final line in whole) {
      if (at < part.length && part[at] == line) at++;
    }
    return at == part.length;
  }

  /// Lines without their leading whitespace, sorted: what moving and
  /// indenting must keep.
  List<String> content(MarkdownLines list) =>
      [for (final l in list.lines) l.raw.trimLeft()]..sort();

  test('parsing keeps the text exactly', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      expect(MarkdownLines.parse(list.text).text, list.text);
    }
  });

  test('toggling and editing an item change only that line', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      final item = randomItem(list);
      if (item == null) continue;
      final index = list.lines.indexOf(item);

      for (final changed in [
        if (item.isCheckbox) list.toggle(item.id),
        list.withBlock(
          item.id,
          ItemBlock(
            kind: item.listKind!,
            checked: item.isChecked,
            depth: list.depthOf(item),
            text: 'new text',
          ),
        ),
      ]) {
        final before = raws(list);
        final after = raws(changed);
        expect(after.length, before.length);
        for (var n = 0; n < before.length; n++) {
          if (n != index) expect(after[n], before[n], reason: 'case $i');
        }
      }
    }
  });

  test('adding an item keeps every other line', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      final item = randomItem(list);
      if (item == null) continue;
      final added = list
          .addItem(
            ListKind.values[random.nextInt(ListKind.values.length)],
            anchor: item.id,
            before: random.nextBool(),
          )
          .$1;

      expect(added.lines.length, list.lines.length + 1);
      expect(isSubsequence(raws(list), raws(added)), isTrue, reason: '$i');
    }
  });

  test('removing keeps every other line in order', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      final item = randomItem(list);
      final removed = item == null || random.nextBool()
          ? list.clearDone()
          : list.remove(item.id);

      expect(isSubsequence(raws(removed), raws(list)), isTrue, reason: '$i');
    }
  });

  test('clearing done items keeps every open item', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      final done = list.doneIds;

      final cleared = list.clearDone();

      expect(cleared.lines.map((l) => l.id).toSet(), {
        for (final l in list.lines)
          if (!done.contains(l.id)) l.id,
      });
    }
  });

  test('moving and indenting keep every line\'s content', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      final item = randomItem(list);
      if (item == null) continue;
      final other = list.lines[random.nextInt(list.lines.length)];

      for (final changed in [
        list.move(item.id, beforeId: other.id),
        list.move(item.id, beforeId: null),
        list.indent(item.id),
        list.indent(item.id, hidden: list.doneIds),
        list.outdent(item.id),
      ]) {
        expect(changed.lines.length, list.lines.length, reason: '$i');
        expect(content(changed), content(list), reason: 'case $i');
      }
    }
  });

  test('toggling and sorting changes only the mark and the order', () {
    for (var i = 0; i < cases; i++) {
      final list = randomList();
      final item = randomItem(list);
      if (item == null || !item.isCheckbox) continue;
      final toggled = list.toggle(item.id);

      final sorted = list.toggleAndSort(item.id);

      expect(content(sorted), content(toggled), reason: 'case $i');
      // Indented lines can belong to a moved item.
      Iterable<String> marginText(MarkdownLines list) => [
        for (final line in list.lines)
          if (!list.isItem(line) && line.indent.isEmpty) line.raw,
      ];
      expect(
        marginText(sorted),
        marginText(toggled),
        reason: 'text lines stay in order, case $i',
      );
    }
  });
}
