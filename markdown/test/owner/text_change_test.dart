import 'package:test/test.dart';
import 'package:truce_markdown/src/owner/history/text_change.dart';

void main() {
  test('finds text added', () {
    expect(textChange('ab', 'axb'), (start: 1, removed: '', added: 'x'));
  });

  test('finds text removed', () {
    expect(textChange('abc', 'ac'), (start: 1, removed: 'b', added: ''));
  });

  test('finds text replaced', () {
    expect(textChange('a cat', 'a dog'), (
      start: 2,
      removed: 'cat',
      added: 'dog',
    ));
  });

  test('finds no change in the same text', () {
    expect(textChange('ab', 'ab'), (start: 2, removed: '', added: ''));
  });

  test('takes repeated text as gone at its end', () {
    expect(textChange('abab', 'ab'), (start: 2, removed: 'ab', added: ''));
  });
}
