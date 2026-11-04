import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  test('a line grows with the text size', () {
    const style = TextStyle(fontSize: 10);
    final normal = lineHeightOf(style, TextScaler.noScaling);
    expect(normal, greaterThan(0));
    expect(lineHeightOf(style, const TextScaler.linear(2)), 2 * normal);
  });
}
