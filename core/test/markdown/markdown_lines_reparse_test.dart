import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Parsing a changed version of a document, e.g. after it changed
/// elsewhere.
void main() {
  test('unchanged lines at the start and end keep their ids', () {
    final doc = MarkdownLines.parse('a\nb\nc\nd');

    final changed = doc.reparse('a\nB\nnew\nd');

    final before = [for (final l in doc.lines) l.id];
    final after = [for (final l in changed.lines) l.id];
    expect(changed.text, 'a\nB\nnew\nd');
    expect(after.first, before.first);
    expect(after.last, before.last);
    expect(before, isNot(contains(after[1])));
    expect(before, isNot(contains(after[2])));
  });

  test('changed lines get ids never used before', () {
    final doc = MarkdownLines.parse('a');

    final once = doc.reparse('b');
    final twice = once.reparse('c');

    expect(twice.lines.single.id, isNot(once.lines.single.id));
    expect(twice.lines.single.id, isNot(doc.lines.single.id));
  });

  test('a line is kept at most once', () {
    final doc = MarkdownLines.parse('a\na');

    final changed = doc.reparse('a');

    expect(changed.lines, hasLength(1));
  });
}
