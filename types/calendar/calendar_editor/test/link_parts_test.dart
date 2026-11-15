import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/src/ui/link_parts.dart';

void main() {
  test('cuts a text into plain stretches and its bare links', () {
    expect(linkParts('Call at https://meet.example.org/a, or mail a@b.org'), [
      (text: 'Call at ', link: null),
      (
        text: 'https://meet.example.org/a',
        link: Uri.parse('https://meet.example.org/a'),
      ),
      (text: ', or mail ', link: null),
      (text: 'a@b.org', link: Uri.parse('mailto:a@b.org')),
    ]);
  });

  test('a text without links is one plain stretch; an empty one none', () {
    expect(linkParts('Town hall'), [(text: 'Town hall', link: null)]);
    expect(linkParts(''), isEmpty);
  });
}
