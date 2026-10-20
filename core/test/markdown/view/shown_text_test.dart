import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// A block's text shown with its syntax hidden and references replaced,
/// and the offsets between the two.
void main() {
  /// The markup of [source], the text of the only leaf it reads as.
  List<MarkupSpan> markupOf(String source) {
    final document = MarkdownDocument.parse(source);
    return LeafView.of(document, document.leaves.single).markupOf(source);
  }

  ShownText formatted(String source) => ShownText.of(source, markupOf(source));

  test('hides syntax and keeps styles in shown offsets', () {
    final shown = formatted('# A **b** [c](u)');

    expect(shown.text, 'A b c');
    expect(shown.markup, [
      const MarkupSpan(HeadingMarkup(1), 0, 5),
      const MarkupSpan(BoldMarkup(), 2, 3),
      const MarkupSpan(LinkMarkup('u'), 4, 5),
    ]);
  });

  test("an item's text shows without its marker, which its frame draws", () {
    final document = MarkdownDocument.parse('  - a');
    final view = LeafView.of(document, document.leaves.single);

    expect(ShownText.of(view.text, view.markupOf(view.text)).text, 'a');
  });

  test('maps offsets both ways', () {
    final shown = formatted('a **b** c');

    expect(
      [for (var i = 0; i <= 5; i++) shown.toSource(i)],
      [0, 1, 4, 7, 8, 9],
    );
    expect(
      [for (var i = 0; i <= 9; i++) shown.fromSource(i)],
      [0, 1, 2, 2, 2, 3, 3, 3, 4, 5],
    );
  });

  test('a character reference shows as the character it stands for', () {
    final shown = formatted('a &amp; b');

    expect(shown.text, 'a & b');
    expect(shown.markup, [const MarkupSpan(EntityMarkup('&'), 2, 3)]);
    expect(
      [for (var i = 0; i <= 5; i++) shown.toSource(i)],
      [0, 1, 2, 7, 8, 9],
    );
    expect(shown.fromSource(2), 2);
    expect(shown.fromSource(4), 3, reason: 'inside it: after it');
  });

  test('an image shows as one object, with its url and description', () {
    final shown = formatted('see ![a *cat*](c.png) now');

    expect(shown.text, 'see ￼ now');
    expect(shown.markup, [
      const MarkupSpan(ImageMarkup('c.png', 'a cat'), 4, 5),
    ]);
    expect(shown.toSource(4), 4);
    expect(shown.toSource(5), 21);
    expect(shown.fromSource(21), 5);
  });

  test('a block without markup is the same', () {
    final shown = formatted('plain');

    expect(shown.text, 'plain');
    expect(shown.toSource(3), 3);
    expect(shown.fromSource(5), 5);
  });

  test('as is, every character shows, with all markup but replacements', () {
    const source = '# A **b** &amp;';
    final markup = markupOf(source);
    final shown = ShownText.asIs(source, markup);

    expect(shown.text, source);
    expect(shown.markup, [
      for (final span in markup)
        if (span.markup is! EntityMarkup) span,
    ]);
    expect(shown.markup, contains(const MarkupSpan(SyntaxMarkup(), 0, 2)));
    expect(shown.toSource(4), 4);
    expect(shown.fromSource(9), 9);
    expect(
      shown.toSource(source.length + 3),
      source.length + 3,
      reason: 'text typed before it is styled again maps as is',
    );
  });
}
