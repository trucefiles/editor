import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Code blocks, tables and images, which depend on more than one line.
void main() {
  test('fenced code', () {
    expect(lineKinds(['a', '```dart', '# not a heading', '```', 'b']), [
      LineKind.plain,
      LineKind.fence,
      LineKind.code,
      LineKind.fence,
      LineKind.plain,
    ]);
  });

  test('an unclosed fence runs to the end', () {
    expect(lineKinds(['~~~', 'a', '```']), [
      LineKind.fence,
      LineKind.code,
      LineKind.code,
    ]);
  });

  test('tables need a delimiter row with as many cells', () {
    expect(lineKinds(['| a | b |', '|---|:-:|', '| 1 | 2 |', '', 'x | y']), [
      LineKind.table,
      LineKind.table,
      LineKind.table,
      LineKind.plain,
      LineKind.plain,
    ]);
    expect(lineKinds(['a | b', '---']), [LineKind.plain, LineKind.plain]);
    expect(tableRanges(lineKinds(['x', 'a|b', '-|-', 'y'])), [(1, 3)]);
  });

  test('table cells without the delimiter row', () {
    expect(tableCells(['| a | b \\| c |', '|---|---|', '|1|2|']), [
      ['a', 'b | c'],
      ['1', '2'],
    ]);
  });

  test('an image alone on its line', () {
    expect(lineImage('![A cat](img/cat.png "Title")'), (
      alt: 'A cat',
      url: 'img/cat.png',
    ));
    expect(lineImage('see ![a](b.png)'), isNull);
  });
}
