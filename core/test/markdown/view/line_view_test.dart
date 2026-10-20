import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// How a line shows in an editor.
void main() {
  LineView viewOf(
    String text,
    int index, {
    bool blocks = true,
    bool caret = false,
  }) {
    final document = MarkdownLines.parse(text);
    final line = document.lines[index];
    return LineView.of(
      document,
      line,
      blocks: blocks,
      caretLine: caret ? line.id : null,
    );
  }

  test('an item shows its text after the marker, at its level', () {
    final view = viewOf('- a\n  3. **b**', 1);

    expect(view.text, '**b**');
    expect(view.item, (
      kind: ListKind.numbered,
      depth: 1,
      checked: false,
      number: 3,
    ));
    expect(view.markupOf(view.text), itemTextMarkup('**b**'));
  });

  test('a checked box shows checked', () {
    expect(viewOf('- [x] done', 0).item?.checked, isTrue);
  });

  test('other lines show whole, a quote as one', () {
    final view = viewOf('> q\nlazy', 1);

    expect(view.item, isNull);
    expect(view.text, 'lazy');
    expect(view.quote, isTrue);
  });

  test('without blocks, every line shows as text', () {
    final item = viewOf('- a', 0, blocks: false);
    final quote = viewOf('> q', 0, blocks: false);

    expect((item.item, item.text), (null, '- a'));
    expect(quote.quote, isFalse);
  });

  test(
    'an item whose marker ends it shows as text while the caret is in it',
    () {
      final held = viewOf('-', 0, caret: true);
      expect((held.item, held.held, held.text), (null, true, '-'));
      expect(viewOf('-', 0).item, isNotNull);
      expect(viewOf('- a', 0, caret: true).item, isNotNull);
      expect(viewOf('- a', 0, caret: true).held, isFalse);
      expect(viewOf('a', 0, caret: true).held, isFalse);
    },
  );

  test('an item shows as one, also with a quote as its text', () {
    final item = viewOf('- > a', 0);
    final quote = viewOf('> - a', 0);

    expect(
      (item.item?.kind, item.quote, item.text),
      (ListKind.bullet, false, '> a'),
    );
    expect((quote.item, quote.quote, quote.text), (null, true, '> - a'));
  });

  test('a line in a code block keeps its kind', () {
    final view = viewOf('```\n- a\n```', 1);

    expect((view.kind, view.item), (LineKind.code, null));
  });
}
