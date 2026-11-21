import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/image_links.dart';

String? _toUp(String destination) =>
    destination.startsWith('document-images/') ? '../$destination' : null;

void main() {
  group('imageLinksOf', () {
    test('gives where inline and reference images lead', () {
      expect(
        imageLinksOf(
          '# A ![](a.png)\n\n- ![x](b/c.jpg "t")\n\n![r][1]\n\n'
          '[1]: d.png\n',
        ),
        {'a.png', 'b/c.jpg', 'd.png'},
      );
    });

    test('gives where the images in a table lead', () {
      expect(
        imageLinksOf(
          '| a | b |\n|---|---|\n| ![](a.png) | [![x](b/c.jpg)](https://e.org) |\n',
        ),
        {'a.png', 'b/c.jpg'},
      );
    });

    test('never finds a link in code or plain text', () {
      expect(
        imageLinksOf(
          '`![](a.png)`\n\n```\n![](b.png)\n```\n\ndocument-images/c.png\n',
        ),
        isEmpty,
      );
    });
  });

  group('relinkedMarkdown', () {
    test('changes only the image links asked, every other block as read', () {
      const text =
          '# Trip\n\n'
          '*  odd   list*\n\n'
          'Look: ![](document-images/img-0123456789abcdef.jpg) there\n\n'
          '![a cat](https://example.org/cat.png)\n';
      expect(
        relinkedMarkdown(text, _toUp),
        '# Trip\n\n'
        '*  odd   list*\n\n'
        'Look: ![](../document-images/img-0123456789abcdef.jpg) there\n\n'
        '![a cat](https://example.org/cat.png)\n',
      );
    });

    test('keeps the description and title', () {
      expect(
        relinkedMarkdown('![x *y*](document-images/a.png "t")\n', _toUp),
        '![x *y*](../document-images/a.png "t")\n',
      );
    });

    test('is null when nothing changes', () {
      expect(relinkedMarkdown('![](img/a.png)\n\ntext\n', _toUp), isNull);
    });

    test('leaves reference images to their definitions', () {
      const text = '![a][1]\n\n[1]: document-images/a.png\n';
      expect(relinkedMarkdown(text, _toUp), isNull);
    });

    test('works on a pasted part without a last line break', () {
      expect(
        relinkedMarkdown('![](document-images/a.png)', _toUp),
        '![](../document-images/a.png)',
      );
    });

    test('finds images in lists and quotes', () {
      expect(
        relinkedMarkdown(
          '- [ ] a\n- ![](document-images/a.png)\n\n> ![](document-images/b.png)\n',
          _toUp,
        ),
        '- [ ] a\n- ![](../document-images/a.png)\n\n'
        '> ![](../document-images/b.png)\n',
      );
    });
  });
}
