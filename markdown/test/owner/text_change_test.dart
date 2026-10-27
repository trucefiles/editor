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

  test('never cuts a character made of two code units in two', () {
    // 😀 and 😁 share their first code unit.
    expect(textChange('a😀b', 'a😁b'), (start: 1, removed: '😀', added: '😁'));
  });

  test('never cuts one in two at the change end', () {
    // U+1F600 and U+1FA00 share their second code unit.
    expect(textChange('a\u{1F600}b', 'a\u{1FA00}b'), (
      start: 1,
      removed: '\u{1F600}',
      added: '\u{1FA00}',
    ));
  });
}
