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
}
