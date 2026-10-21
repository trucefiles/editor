import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// A leaf's text as plain words.
void main() {
  String plain(String source) {
    final document = MarkdownDocument.parse(source);
    return document.plainTextOf(document.leaves.first);
  }

  test('drops block and inline marks', () {
    expect(plain('# **Big** *news*'), 'Big news');
    expect(plain('> - [ ] a [link](u)'), 'a link');
    expect(plain('a\\\nb'), 'a\nb');
  });

  test('drops images and decodes references', () {
    expect(plain('a ![pic](p.png) &amp; b'), 'a  & b');
  });

  test('code without fences, tables by their cells, none for rules', () {
    expect(plain('```dart\nx = 1\n```'), 'x = 1');
    expect(plain('| a | b |\n|---|---|\n| 1 | 2 |'), 'a b\n1 2');
    expect(plain('---'), '');
    expect(plain('---\ntitle: x\n---'), '');
  });
}
