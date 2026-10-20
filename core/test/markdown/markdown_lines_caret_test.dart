import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Places in lines across changes of their list marker.
void main() {
  test('textStartOf is past an item marker, else 0', () {
    final doc = MarkdownLines.parse('- [ ] a\ntext\n```\n- b\n```');

    expect(
      [for (final line in doc.lines) doc.textStartOf(line)],
      [6, 0, 0, 0, 0],
    );
  });

  test('a caret keeps its place in the text when the marker changes', () {
    final before = MarkdownLines.parse('milk');
    final line = before.lines.single.id;
    final (after, _) = before.toList([line], ListKind.checkbox);

    expect(before.caretIn(after, (line: line, offset: 2)), (
      line: line,
      offset: 8,
    ));
    expect(after.caretIn(before, (line: line, offset: 1)), (
      line: line,
      offset: 0,
    ));
  });

  test('a caret on a line that is gone has no place', () {
    final before = MarkdownLines.parse('a\nb');
    final line = before.lines.last.id;

    expect(
      before.caretIn(before.removeLine(line), (line: line, offset: 0)),
      isNull,
    );
  });
}
