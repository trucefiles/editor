import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// How Markdown marks show in each style.
void main() {
  const source = 'a **b**';
  final document = MarkdownDocument.parse(source);
  final markup = LeafView.of(document, document.leaves.single).markupOf(source);

  String shown(MarkStyle style, {required bool edited}) =>
      style.show(source, markup, edited: edited).text;

  test('shown keeps every mark', () {
    expect(shown(MarkStyle.shown, edited: false), source);
    expect(shown(MarkStyle.shown, edited: true), source);
  });

  test('mixed hides marks except in the block being edited', () {
    expect(shown(MarkStyle.mixed, edited: false), 'a b');
    expect(shown(MarkStyle.mixed, edited: true), source);
  });
}
