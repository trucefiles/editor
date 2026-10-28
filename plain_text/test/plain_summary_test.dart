import 'package:test/test.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

void main() {
  PlainSummary summary(String text, {int maxLines = 10}) =>
      const PlainTextSupport().summary(text, maxLines: maxLines);

  test('the first line with words is the title', () {
    expect(summary('\n  Shopping  \nmilk').title, 'Shopping');
    expect(summary('\n  Shopping  \nmilk').firstLine, 'Shopping');
  });

  test('an empty text has no title', () {
    expect(summary(' \n\n').title, isNull);
    expect(summary('').firstLine, '');
  });

  test('the preview is the lines with words after the title, as written', () {
    expect(
      summary('Title\r\n\r\n  - milk  \r\n# not a heading')
          .preview(const PlainPreview()),
      '  - milk\n# not a heading',
    );
  });

  test('the preview holds up to its most lines', () {
    expect(
      summary('t\n1\n2\n3', maxLines: 2).preview(const PlainPreview()),
      '1\n2',
    );
  });

  test('handles .txt files, in any case', () {
    expect(const PlainTextSupport().extensions, {'txt'});
    expect(const PlainTextSupport().type, plainTextType);
  });
}
