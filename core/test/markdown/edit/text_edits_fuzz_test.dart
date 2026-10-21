import 'dart:math';

import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Seeded random text edits in random views, as an editor showing the
/// arranged document makes them: lines an edit does not reach keep their
/// bytes, ids and order, and the file text is the one the edit makes.
void main() {
  const cases = 600;
  const steps = 12;
  // Lines, and runs of lines whose blocks take several.
  const pieces = [
    '- [ ] open',
    '- [x] done\n  more',
    '  - [ ] sub\n    more',
    '    * [X] deep',
    '- tight\n  continued\n  again',
    '-',
    '1. [ ] numbered\n   more',
    '  2) numbered sub',
    '* bullet\n\n  later',
    '# Heading **bold**',
    'plain text  \nmore',
    r'hard\',
    '  continued',
    '    indented code\n    more',
    '',
    '> quote\n> more',
    '> - quoted item\n>   more',
    '>',
    '```\ncode line\n```',
    '```',
    '---',
    'Title\n===',
    '| a | b |\n|---|---|\n| 1 | 2 |',
    '[ref]: https://x.org',
    'a &amp; b ![i](x.png)',
  ];
  const texts = [
    'x',
    '',
    '',
    ' lead',
    'trail ',
    '**b**',
    '\n',
    'a\nb',
    '- [ ] y',
    '> ',
    '```',
    r'\',
    '\n\n',
  ];

  test('untouched lines keep their bytes; the text is as edited', () {
    final random = Random(11);
    var checked = 0;
    for (var c = 0; c < cases; c++) {
      var document = MarkdownDocument.parse(
        [
          for (var i = random.nextInt(12) + 1; i > 0; i--)
            pieces[random.nextInt(pieces.length)],
        ].join('\n'),
      );
      for (var s = 0; s < steps; s++) {
        final edit = _Edit.random(
          random,
          document,
          texts[random.nextInt(texts.length)],
        );
        final (next, caret) = document.replaceText(
          edit.from,
          edit.to,
          edit.text,
          removed: edit.removed,
        );
        if (edit.check(document, next, caret)) checked++;
        document = next;
      }
    }
    expect(checked, greaterThan(cases * steps * 3 ~/ 4));
  });
}

/// The views an editor shows of [document]: one per leaf, or one per
/// line; an empty item the caret is in held as text.
List<EditView> _views(Random random, MarkdownDocument document) {
  if (random.nextBool()) {
    return [for (final line in document.lines) RawLineView.of(document, line)];
  }
  final caretLine = document.lines[random.nextInt(document.lines.length)].id;
  return [
    for (final leaf in document.leaves)
      LeafView.of(document, leaf, caretLine: caretLine),
  ];
}

/// One random text edit, from a place in one view to a place in the
/// same or a later one.
final class _Edit {
  _Edit(this.from, this.to, this.text, this.removed);

  factory _Edit.random(Random random, MarkdownDocument document, String text) {
    final views = _views(random, document);
    final first = random.nextInt(views.length);
    final last = random.nextInt(4) == 0
        ? first + random.nextInt(views.length - first)
        : first;
    final start = _offset(random, views[first].text, 0);
    final lineEnd = views[first].text.indexOf('\n', start);
    final end = first == last && lineEnd >= 0 && random.nextInt(3) == 0
        ? lineEnd + 1
        : _offset(random, views[last].text, first == last ? start : 0);
    return _Edit(
      (view: views[first], offset: start),
      (view: views[last], offset: end),
      text,
      views.sublist(first + 1, max(first + 1, last)),
    );
  }

  /// A random offset in [text] from [least] on: often where a line
  /// starts or ends, where edits change which lines there are. An edit
  /// to the start of the next line takes the rest of a line with it.
  static int _offset(Random random, String text, int least) {
    final bounds = [
      0,
      for (final (index, char) in text.split('').indexed)
        if (char == '\n') ...[index, index + 1],
      text.length,
    ].where((offset) => offset >= least).toList();
    return random.nextInt(4) > 0
        ? bounds[random.nextInt(bounds.length)]
        : least + random.nextInt(text.length - least + 1);
  }

  @override
  String toString() =>
      '${from.view.runtimeType} ${from.view.text}@${from.offset} to '
      '${to.view.text}@${to.offset}, ${removed.length} between, with $text';

  final ViewPlace from;
  final ViewPlace to;
  final String text;
  final List<EditView> removed;

  /// Where the edit starts in effect: a line break deleted alone in a
  /// structured view takes its hard break along.
  ViewPlace get _from =>
      from.view is LeafView &&
          to.view == from.view &&
          text.isEmpty &&
          to.offset == from.offset + 1 &&
          hardBreakBefore(from.view.text, to.offset)
      ? (view: from.view, offset: from.offset - 1)
      : from;

  /// Checks [after], with [caret], the document [before] with this edit;
  /// returns whether the edit was one whose file text this can tell.
  bool check(MarkdownDocument before, MarkdownDocument after, LineCaret caret) {
    final reason =
        'edit: $this\nbefore:\n${before.text}\nafter:\n${after.text}';
    final ids = [for (final line in after.lines) line.id];
    expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
    final start = _from.view.caretAt(_from.offset);
    final end = to.view == _from.view
        ? to.view.caretAt(to.offset)
        : (line: to.view.lines.last.line.id, offset: -1);
    final firstIndex = before.indexOf(start.line);
    final lastIndex = before.indexOf(end.line);
    final kept = [
      ...before.lines.take(firstIndex),
      ...before.lines.skip(lastIndex + 1),
    ];
    final afterById = {for (final line in after.lines) line.id: line};
    for (final line in kept) {
      expect(afterById[line.id]?.raw, line.raw, reason: reason);
    }
    expect(
      [
        for (final line in after.lines)
          if (kept.any((k) => k.id == line.id)) line.id,
      ],
      [for (final line in kept) line.id],
      reason: reason,
    );
    if (!_uniform(_from.view) || _blankBelowBox) return false;
    final (expected, caretAt) = _expected(before);
    expect(after.text, expected, reason: reason);
    expect(_offsetIn(after, caret), caretAt, reason: reason);
    return true;
  }

  /// The file text of [before] with this edit, and where the caret goes
  /// in it: the edited range of the file replaced, each new line with
  /// the prefix its view gives it, the lines of the last view after the
  /// range going on in the first view's blocks.
  (String, int) _expected(MarkdownDocument before) {
    final view = _from.view;
    final startCaret = view.caretAt(_from.offset);
    final startLine = view.lines.firstWhere(
      (line) => line.line.id == startCaret.line,
    );
    final above = startLine.line.raw.substring(0, startLine.start);
    // Each new line with its prefix: after a blank new line, as the view
    // gives it there.
    String prefixed(String text) => [
      for (final (index, line) in text.split('\n').indexed)
        index == 0
            ? line
            : '${view.newLinePrefix(above, afterBlank: text.split('\n').sublist(1, index).any((line) => line.trim().isEmpty))}$line',
    ].join('\n');
    final rest = to.view.text.substring(to.offset);
    final same = to.view == view;
    final inserted = prefixed('$text${same ? '' : rest}');
    final spaced =
        startLine.start == startLine.end &&
        inserted.split('\n').first.isNotEmpty &&
        startLine.start > 0 &&
        !' \t'.contains(startLine.line.raw[startLine.start - 1]);
    final startOffset = _offsetIn(before, startCaret);
    final endOffset = same
        ? _offsetIn(before, to.view.caretAt(to.offset))
        : _offsetIn(before, (
            line: to.view.lines.last.line.id,
            offset: to.view.lines.last.end,
          ));
    final caretText = prefixed(text);
    return (
      before.text.replaceRange(
        startOffset,
        endOffset,
        '${spaced ? ' ' : ''}$inserted',
      ),
      startOffset + (spaced ? 1 : 0) + caretText.length,
    );
  }

  /// Whether a blank line comes into a view whose lines after a blank
  /// line start elsewhere than below text (a task box), so lines kept
  /// below it no longer have the prefix new lines get.
  bool get _blankBelowBox {
    final first = _from.view.lines.first;
    final prefix = first.line.raw.substring(0, first.start);
    return _from.view.newLinePrefix(prefix) !=
            _from.view.newLinePrefix(prefix, afterBlank: true) &&
        '$text${to.view.text.substring(to.offset)}'
            .split('\n')
            .skip(1)
            .any((line) => line.trim().isEmpty);
  }

  /// Whether the prefix of each line of [view] but the first is the one
  /// it gives new lines, so which line keeps which prefix does not change
  /// the file text: no lazy lines, no prefixes written differently.
  static bool _uniform(EditView view) {
    final first = view.lines.first;
    final continued = view.newLinePrefix(
      first.line.raw.substring(0, first.start),
    );
    return view.lines
        .skip(1)
        .every((line) => line.line.raw.substring(0, line.start) == continued);
  }

  /// Where [caret] is in the text of [document].
  static int _offsetIn(MarkdownDocument document, LineCaret caret) =>
      document.lines
          .take(document.indexOf(caret.line))
          .map((line) => line.raw.length + 1)
          .sum +
      caret.offset;
}
