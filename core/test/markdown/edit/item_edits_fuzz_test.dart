import 'dart:math';

import 'package:collection/collection.dart';
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
    // A rule; `---` would read as front matter once at the top.
    '***',
    '> - [ ] quoted',
    '>   - [x] quoted sub',
    '> quote text',
  ];

  late Random random;

  setUp(() => random = Random(7));

  MarkdownDocument randomDocument() => MarkdownDocument.parse(
    [
      for (var i = random.nextInt(10) + 1; i > 0; i--)
        lineKinds[random.nextInt(lineKinds.length)],
    ].join('\n'),
  );

  ItemBlock? randomItem(MarkdownDocument document) {
    final items = document.outline.items;
    return items.isEmpty ? null : items[random.nextInt(items.length)];
  }

  MarkdownLine randomLine(MarkdownDocument document) =>
      document.lines[random.nextInt(document.lines.length)];

  String shown(MarkdownDocument document) =>
      document.text.replaceAll('\n', r'\n');

  List<String> raws(MarkdownDocument document) => [
    for (final line in document.lines) line.raw,
  ];

  int depthIn(MarkdownDocument document, LineId id) =>
      document.outline.lineDepth(id);

  bool isItem(MarkdownDocument document, LineId id) =>
      document.outline.itemOf(id) != null;

  /// Whether [part] appears in [whole] in the same order.
  bool isSubsequence(List<String> part, List<String> whole) =>
      whole.fold(
        0,
        (at, line) => at < part.length && part[at] == line ? at + 1 : at,
      ) ==
      part.length;

  /// Lines without their leading whitespace, quote marks and numbers,
  /// sorted: what moving and indenting must keep. A lazy line may get the
  /// quote marks it was in, and a number may change when an item starts a
  /// new list.
  List<String> content(MarkdownDocument document) => [
    for (final line in document.lines)
      line.raw.replaceFirst(RegExp(r'^[\s>]*\d*'), ''),
  ]..sort();

  /// The lines in a quote.
  Set<LineId> quoted(MarkdownDocument document) => {
    for (final line in document.lines)
      if (document
          .leafOf(line.id)
          .ancestors
          .any((block) => block is QuoteBlock))
        line.id,
  };

  test('parsing keeps the text exactly', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      expect(MarkdownDocument.parse(document.text).text, document.text);
    }
  });

  test('toggling an item changes only that line', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null || item.checked == null) continue;
      final index = document.indexOf(item.markerLine);

      final before = raws(document);
      final after = raws(document.toggle(item.markerLine));

      expect(after.length, before.length);
      expect(
        after[index],
        isNot(before[index]),
        reason: 'case $i: ${shown(document)}',
      );
      expect(
        [...after]..removeAt(index),
        [...before]..removeAt(index),
        reason: 'case $i: ${shown(document)}',
      );
    }
  });

  test('adding an item keeps every other line', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null) continue;
      final (added, id) = document.addItem(
        ListKind.values[random.nextInt(ListKind.values.length)],
        anchor: item.markerLine,
        before: random.nextBool(),
      );

      expect(added.lines.length, document.lines.length + 1);
      expect(isItem(added, id), isTrue, reason: 'case $i: ${shown(document)}');
      expect(
        isSubsequence(raws(document), raws(added)),
        isTrue,
        reason: 'case $i: ${shown(document)}',
      );
    }
  });

  test('removing keeps every other line in order', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      final removed = item == null || random.nextBool()
          ? document.clearDone()
          : document.remove(item.markerLine);

      expect(
        isSubsequence(raws(removed), raws(document)),
        isTrue,
        reason: 'case $i: ${shown(document)}',
      );
    }
  });

  test('clearing done items keeps every open item', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final done = document.outline.doneIds;

      final cleared = document.clearDone();

      expect(cleared.lines.map((line) => line.id).toSet(), {
        for (final line in document.lines)
          if (!done.contains(line.id)) line.id,
      });
    }
  });

  test('moving and indenting keep every line\'s content', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null) continue;
      final id = item.markerLine;
      final other = randomLine(document);

      for (final changed in [
        document.move(id, beforeId: other.id),
        document.move(id, beforeId: null),
        document.indent(id),
        document.indent(id, hidden: document.outline.doneIds),
        document.outdent(id),
      ]) {
        expect(
          changed.lines.length,
          document.lines.length,
          reason: 'case $i: ${shown(document)}',
        );
        expect(
          content(changed),
          content(document),
          reason: 'case $i: ${shown(document)}',
        );
      }
      for (final changed in [document.indent(id), document.outdent(id)]) {
        expect(
          quoted(changed),
          quoted(document),
          reason: 'quotes stay, case $i: ${shown(document)}',
        );
      }
    }
  });

  test('indent, outdent and drop give the level asked for', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null) continue;
      final id = item.markerLine;
      final depth = document.outline.depthOf(item);
      final target = randomLine(document);
      final below = random.nextBool();
      final dropped = document.moveNextTo(id, target: target.id, below: below);
      final indented = document.indent(id);
      final outdented = document.outdent(id);
      final reason = 'case $i: ${shown(document)}';

      if (indented.text != document.text) {
        expect(isItem(indented, id), isTrue, reason: 'indent $reason');
        expect(depthIn(indented, id), depth + 1, reason: 'indent $reason');
      }
      if (depth > 0) {
        expect(isItem(outdented, id), isTrue, reason: 'outdent $reason');
        expect(depthIn(outdented, id), depth - 1, reason: 'outdent $reason');
      }
      if (dropped.text != document.text && isItem(document, target.id)) {
        final next = document.lines
            .elementAtOrNull(document.indexOf(target.id) + 1)
            ?.id;
        final level =
            below &&
                next != null &&
                isItem(document, next) &&
                depthIn(document, next) > depthIn(document, target.id)
            ? depthIn(document, next)
            : depthIn(document, target.id);
        expect(isItem(dropped, id), isTrue, reason: 'drop $reason');
        expect(depthIn(dropped, id), level, reason: 'drop $reason');
      }
    }
  });

  test('a moved item keeps its subitems at their levels under it', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null) continue;
      final id = item.markerLine;
      final target = randomLine(document);
      final (:start, :end) = document.outline.subtree(item);
      final under = document.lines
          .sublist(start + 1, end)
          .where((line) => !line.isBlank);

      for (final changed in [
        document.moveNextTo(id, target: target.id, below: random.nextBool()),
        document.indent(id),
        document.outdent(id),
      ]) {
        final shift = depthIn(changed, id) - depthIn(document, id);
        for (final line in under) {
          expect(
            depthIn(changed, line.id),
            depthIn(document, line.id) + shift,
            reason: 'case $i: ${shown(document)}',
          );
        }
      }
    }
  });

  test('a new item leaves every other line at its level', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null) continue;
      final (added, id) = document.addItem(
        ListKind.values[random.nextInt(ListKind.values.length)],
        anchor: item.markerLine,
        before: random.nextBool(),
      );
      final newItem = added.outline.itemOf(id)!;

      // Markdown nests a line indented to the new item's content under
      // it, e.g. an item of another list indented by two below an empty
      // `- `; every other line keeps its level.
      for (final line in document.lines.where(
        (line) =>
            !line.isBlank && !added.outline.itemsAt(line.id).contains(newItem),
      )) {
        expect(
          depthIn(added, line.id),
          depthIn(document, line.id),
          reason: 'case $i: ${shown(document)}',
        );
      }
    }
  });

  test('toggling and sorting changes only the mark and the order', () {
    for (var i = 0; i < cases; i++) {
      final document = randomDocument();
      final item = randomItem(document);
      if (item == null || item.checked == null) continue;
      final toggled = document.toggle(item.markerLine);

      final sorted = document.toggleAndSort(item.markerLine);

      expect(
        content(sorted),
        content(toggled),
        reason: 'case $i: ${shown(document)}',
      );
      // Lines under a moved item move with it, blank lines among them;
      // text in no item stays in order.
      final text = {
        for (final line in toggled.lines)
          if (toggled.outline.itemsAt(line.id).isEmpty && !line.isBlank)
            line.id,
      };
      Iterable<String> textIn(MarkdownDocument document) => [
        for (final line in document.lines)
          if (text.contains(line.id)) line.raw,
      ];
      expect(
        textIn(sorted),
        textIn(toggled),
        reason: 'text lines stay in order, case $i',
      );
      expect(
        sorted.outline.items.map((item) => item.markerLine).toSet(),
        toggled.outline.items.map((item) => item.markerLine).toSet(),
        reason: 'items stay items, case $i: ${shown(toggled)}',
      );
    }
  });
}
