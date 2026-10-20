import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// How Markdown marks show in each style.
void main() {
  const source = 'a **b**';
  final markup = lineMarkup(source, LineKind.plain);

  String shown(MarkStyle style, {required bool edited}) =>
      style.show(source, markup, edited: edited).text;

  test('shown keeps every mark', () {
    expect(shown(MarkStyle.shown, edited: false), source);
    expect(shown(MarkStyle.shown, edited: true), source);
  });

  test('mixed hides marks except on edited lines', () {
    expect(shown(MarkStyle.mixed, edited: false), 'a b');
    expect(shown(MarkStyle.mixed, edited: true), source);
  });

  test('hidden hides every mark', () {
    expect(shown(MarkStyle.hidden, edited: false), 'a b');
    expect(shown(MarkStyle.hidden, edited: true), 'a b');
  });
}
