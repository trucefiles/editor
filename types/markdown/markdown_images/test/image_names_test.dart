import 'package:test/test.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'support.dart';

void main() {
  test('a new name follows the rule', () {
    final name = ImageNames.newName('png');
    expect(ImageNames.nameIn(name), name);
    expect(ImageNames.newName('png'), isNot(name));
  });

  test('a link is ours by its name only, wherever it points', () {
    expect(ImageNames.nameIn('document-images/$nameA'), nameA);
    expect(ImageNames.nameIn('../../document-images/$nameA'), nameA);
    expect(ImageNames.nameIn('pics/$nameA'), nameA);
    expect(ImageNames.nameIn('https://example.com/$nameA'), isNull);
    expect(ImageNames.nameIn('document-images/$nameA?x=1'), isNull);
    expect(ImageNames.nameIn('document-images/photo.png'), isNull);
    expect(ImageNames.nameIn('img-0123.png'), isNull);
  });

  test('the link from a document goes up to the root first', () {
    expect(ImageNames.linkFrom(null, nameA), 'document-images/$nameA');
    expect(
      ImageNames.linkFrom(path('a/b'), nameA),
      '../../document-images/$nameA',
    );
  });

  test('a document links the names of ours its images lead to', () {
    expect(
      ImageNames.linkedBy(
        '![](document-images/$nameA) and $nameB, `![](x/$nameB)`, '
        '![](../document-images/$nameA) ![](pics/a.png)',
      ),
      {nameA},
    );
  });

  test('links from documents at the same depth read alike', () {
    expect(ImageNames.linksAlike(null, null), isTrue);
    expect(ImageNames.linksAlike(path('a'), path('b')), isTrue);
    expect(ImageNames.linksAlike(null, path('a')), isFalse);
    expect(ImageNames.linksAlike(path('a/b'), path('c')), isFalse);
  });

  test('a link of ours is kept in the store, wherever it points', () {
    expect(ImageNames.keptAt('../../x/$nameA'), path('document-images/$nameA'));
    expect(ImageNames.keptAt('pics/a.png'), isNull);
  });

  test('the store folder and all in it are kept apart', () {
    expect(ImageNames.isKept(path('document-images')), isTrue);
    expect(ImageNames.isKept(path('document-images/$nameA')), isTrue);
    expect(ImageNames.isKept(path('notes/document-images')), isFalse);
    expect(ImageNames.isKept(path('a.md')), isFalse);
  });
}
