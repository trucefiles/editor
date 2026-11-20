import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  /// The step of the edit from [before] to [after].
  TextStep stepOf(String before, String after) =>
      TextStep(textChange(before, after));

  group('a text step', () {
    test('undone puts back what went, the caret after it', () {
      expect(stepOf('a cat', 'a dog').undoneIn('a dog'), (
        text: 'a cat',
        caret: 5,
      ));
    });

    test('redone makes the edit again, the caret after what it added', () {
      expect(stepOf('ab', 'axyb').redoneIn('ab'), (text: 'axyb', caret: 3));
    });

    test('keeps only the change', () {
      final step = stepOf('long text here', 'long next here');

      expect(step.change, (start: 5, removed: 't', added: 'n'));
    });

    test('applied to a text it is not of is a bug', () {
      expect(() => stepOf('ab', 'ax').undoneIn('ab'), throwsStateError);
      expect(() => stepOf('ab', 'abc').undoneIn('a'), throwsStateError);
    });

    test('joined with typing that goes on is one step', () {
      final joined = stepOf('ab', 'axb').joined(stepOf('axb', 'axyb'));

      expect(joined.change, (start: 1, removed: '', added: 'xy'));
      expect(joined.undoneIn('axyb'), (text: 'ab', caret: 1));
    });
  });

  group('changes followed by one another', () {
    TextChange both(String a, String b, String c) =>
        followedBy(textChange(a, b), textChange(b, c));

    test('typing on', () {
      expect(both('ab', 'axb', 'axyb'), (start: 1, removed: '', added: 'xy'));
    });

    test('backspace on', () {
      expect(both('abc', 'ab', 'a'), (start: 1, removed: 'bc', added: ''));
    });

    test('delete on', () {
      expect(both('abc', 'ac', 'a'), (start: 1, removed: 'bc', added: ''));
    });

    test('a word replaced as it is composed', () {
      expect(both('', 'hel', 'help'), (start: 0, removed: '', added: 'help'));
    });

    test('a change reaching past both ends of the first', () {
      expect(
        followedBy(
          (start: 2, removed: 'c', added: 'X'),
          (start: 1, removed: 'bXd', added: 'Y'),
        ),
        (start: 1, removed: 'bcd', added: 'Y'),
      );
    });
  });
}
