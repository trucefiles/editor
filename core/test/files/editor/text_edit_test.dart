import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  group('a text edit', () {
    test('is the text before with its change made', () {
      final edit = TextEdit('a cat', (start: 2, removed: 'cat', added: 'dog'));

      expect(edit.text, 'a dog');
      expect(edit.changes, isTrue);
    });

    test('of a change not of the text before is a bug', () {
      expect(
        () => TextEdit('a cat', (start: 2, removed: 'dog', added: 'x')),
        throwsStateError,
      );
      expect(
        () => TextEdit('ab', (start: 1, removed: 'bc', added: '')),
        throwsStateError,
      );
    });

    test('that puts back what it takes changes nothing', () {
      expect(
        TextEdit('ab', (start: 1, removed: 'b', added: 'b')).changes,
        isFalse,
      );
    });
  });

  test('a change reversed takes it back', () {
    const change = (start: 1, removed: 'b', added: 'xy');

    expect(
      applyChange(applyChange('abc', change), reversedChange(change)),
      'abc',
    );
  });
}
