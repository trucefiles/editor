import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// A line shown with its syntax hidden, and the offsets between the two.
void main() {
  ShownLine visual(String line) =>
      ShownLine.of(line, lineMarkup(line, LineKind.plain));

  test('hides syntax and keeps styles in shown offsets', () {
    final line = visual('# A **b** [c](u)');

    expect(line.text, 'A b c');
    expect(line.markup, [
      const MarkupSpan(HeadingMarkup(1), 0, 5),
      const MarkupSpan(BoldMarkup(), 2, 3),
      const MarkupSpan(LinkMarkup('u'), 4, 5),
    ]);
  });

  test('hides list markers: items show as list items', () {
    expect(visual('  - a').text, '  a');
  });

  test('maps offsets both ways', () {
    final line = visual('a **b** c');

    expect([for (var i = 0; i <= 5; i++) line.toSource(i)], [0, 1, 4, 7, 8, 9]);
    expect(
      [for (var i = 0; i <= 9; i++) line.fromSource(i)],
      [0, 1, 2, 2, 2, 3, 3, 3, 4, 5],
    );
  });

  test('a line without markup is the same', () {
    final line = visual('plain');

    expect(line.text, 'plain');
    expect(line.toSource(3), 3);
    expect(line.fromSource(5), 5);
  });

  test('as is, every character shows with all markup', () {
    const source = '# A **b**';
    final markup = lineMarkup(source, LineKind.plain);
    final line = ShownLine.asIs(source, markup);

    expect(line.text, source);
    expect(line.markup, markup);
    expect(line.toSource(4), 4);
    expect(line.fromSource(9), 9);
    expect(
      line.toSource(source.length + 3),
      source.length + 3,
      reason: 'text typed before it is styled again maps as is',
    );
  });
}
