import 'package:test/test.dart';
import 'package:truce_documents/truce_documents.dart';

void main() {
  const both = LineOrigin.both;
  const shown = LineOrigin.shownOnly;
  const other = LineOrigin.otherOnly;

  List<(String, LineOrigin)> compared(String shownText, String otherText) => [
    for (final line in compareLines(
      shownText.split('\n'),
      otherText.split('\n'),
    ))
      (line.text, line.origin),
  ];

  test('keeps lines both have, in order', () {
    expect(compared('a\nb', 'a\nb'), [('a', both), ('b', both)]);
  });

  test('shows lines only one version has where they are', () {
    expect(compared('a\nb\nc', 'a\nc\nd'), [
      ('a', both),
      ('b', shown),
      ('c', both),
      ('d', other),
    ]);
  });

  test('a changed line shows the other version first', () {
    expect(compared('a\nB\nc', 'a\nb\nc'), [
      ('a', both),
      ('b', other),
      ('B', shown),
      ('c', both),
    ]);
  });

  test('finds a change below a repeated line', () {
    // The old check matched lines by text anywhere in the other
    // version, so the second `- [ ] milk` counted as unchanged.
    expect(compared('- [ ] milk\n\n- [ ] milk', '- [ ] milk\n\n- [x] milk'), [
      ('- [ ] milk', both),
      ('', both),
      ('- [x] milk', other),
      ('- [ ] milk', shown),
    ]);
  });

  test('a moved line is removed in one place and added in the other', () {
    expect(
      compared('b\na', 'a\nb'),
      anyOf([
        [('a', other), ('b', both), ('a', shown)],
        [('b', shown), ('a', both), ('b', other)],
      ]),
    );
  });

  test('changes in several places, each in order', () {
    expect(compared('a\nB\nc\nd\nE\nf\ng', 'a\nb\nc\nd\ne\nf'), [
      ('a', both),
      ('b', other),
      ('B', shown),
      ('c', both),
      ('d', both),
      ('e', other),
      ('E', shown),
      ('f', both),
      ('g', shown),
    ]);
  });

  test('compares with an empty version', () {
    expect(compared('a', ''), [('', other), ('a', shown)]);
  });
}
