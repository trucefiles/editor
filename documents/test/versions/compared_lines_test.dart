import 'package:test/test.dart';
import 'package:truce_documents/truce_documents.dart';

void main() {
  List<(String, bool)> compared(String shownText, String otherText) => [
    for (final line in compareLines(
      shownText.split('\n'),
      otherText.split('\n'),
    ))
      (line.text, line.onlyHere),
  ];

  test('keeps lines both have, in order', () {
    expect(compared('a\nb', 'a\nb'), [('a', false), ('b', false)]);
  });

  test("shows only this version's lines, marking the ones only it has", () {
    expect(compared('a\nb\nc', 'a\nc\nd'), [
      ('a', false),
      ('b', true),
      ('c', false),
    ]);
  });

  test('a changed line is only here', () {
    expect(compared('a\nB\nc', 'a\nb\nc'), [
      ('a', false),
      ('B', true),
      ('c', false),
    ]);
  });

  test('finds a change below a repeated line', () {
    // Matching lines by text anywhere in the other version would count
    // the second `- [ ] milk` as unchanged.
    expect(compared('- [ ] milk\n\n- [ ] milk', '- [ ] milk\n\n- [x] milk'), [
      ('- [ ] milk', false),
      ('', false),
      ('- [ ] milk', true),
    ]);
  });

  test('a moved line is only here in one of its places', () {
    expect(
      compared('b\na', 'a\nb'),
      anyOf([
        [('b', false), ('a', true)],
        [('b', true), ('a', false)],
      ]),
    );
  });

  test('changes in several places', () {
    expect(compared('a\nB\nc\nd\nE\nf\ng', 'a\nb\nc\nd\ne\nf'), [
      ('a', false),
      ('B', true),
      ('c', false),
      ('d', false),
      ('E', true),
      ('f', false),
      ('g', true),
    ]);
  });

  test('compares with an empty version', () {
    expect(compared('a', ''), [('a', true)]);
  });
}
