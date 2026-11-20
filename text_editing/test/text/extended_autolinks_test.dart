import 'package:test/test.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

/// The links in [text], as the text each shows and where it leads.
List<(String, String)> _links(String text) => [
  for (final (:start, :end, :destination) in findExtendedAutolinks(
    text,
    0,
    text.length,
  ))
    (text.substring(start, end), destination),
];

void main() {
  test('finds scheme urls, www. addresses and email addresses', () {
    expect(
      _links(
        'See https://example.org/a?b=1, www.example.com or mail '
        'me@example.org.',
      ),
      [
        ('https://example.org/a?b=1', 'https://example.org/a?b=1'),
        ('www.example.com', 'http://www.example.com'),
        ('me@example.org', 'mailto:me@example.org'),
      ],
    );
  });

  test('leaves out trailing punctuation and an unmatched closing '
      'parenthesis', () {
    expect(_links('(at www.example.com/a_(b))!'), [
      ('www.example.com/a_(b)', 'http://www.example.com/a_(b)'),
    ]);
  });

  test('finds nothing in plain words or a domain without a period', () {
    expect(_links('Meet at the cafe, room 2. http://localhost'), isEmpty);
  });
}
