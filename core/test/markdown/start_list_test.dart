import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// Starting a checklist at the caret.
void main() {
  test('below the caret line', () {
    final doc = MarkdownLines.parse('a\nb');

    final (started, id) = doc.startList(at: idOf(doc, 'a'));

    expect(started.text, 'a\n- [ ] \nb');
    expect(started.lines[1].id, id);
  });

  test('on the caret line if it is blank', () {
    final doc = MarkdownLines.parse('a\n\nb');

    final (started, id) = doc.startList(at: doc.lines[1].id);

    expect(started.text, 'a\n- [ ] \nb');
    expect(id, doc.lines[1].id);
  });

  test('below an item, at its level and in its style', () {
    final doc = MarkdownLines.parse('  * [x] a');

    final (started, _) = doc.startList(at: idOf(doc, 'a'));

    expect(started.text, '  * [x] a\n  * [ ] ');
  });

  test('without a caret, at the end before the final line break', () {
    final doc = MarkdownLines.parse('a\n');

    expect(doc.startList().$1.text, 'a\n- [ ] \n');
    expect(MarkdownLines.parse('a').startList().$1.text, 'a\n- [ ] ');
  });

  test('in an empty note, as its first line', () {
    expect(MarkdownLines.parse('').startList().$1.text, '- [ ] ');
  });
}
