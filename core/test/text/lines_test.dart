import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('breaks lines at \\n, \\r\\n and a lone \\r', () {
    expect(splitLines('a\nb\r\nc\rd'), ['a', 'b', 'c', 'd']);
  });

  test('a text ending with a break has an empty last line', () {
    expect(splitLines('a\r\n'), ['a', '']);
  });

  test('an empty text is one empty line', () {
    expect(splitLines(''), ['']);
  });

  test('\\r\\n is one break, \\n\\r two', () {
    expect(anyLineBreak.allMatches('\r\n\n\r').map((m) => m[0]), [
      '\r\n',
      '\n',
      '\r',
    ]);
  });

  test('a line starts after the break before it', () {
    expect(
      [
        for (final line in [0, 1, 2, 3]) lineStart('ab\ncd\n', line),
      ],
      [0, 3, 6, 6],
    );
  });

  test('an offset is on the line its break comes after', () {
    expect(
      [
        for (final offset in [0, 2, 3, 6]) lineAt('ab\ncd\n', offset),
      ],
      [0, 0, 1, 2],
    );
  });
}
