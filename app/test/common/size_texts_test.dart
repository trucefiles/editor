import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/size_texts.dart';

void main() {
  test('tells sizes as people read them', () {
    expect(sizeText(0), '0 bytes');
    expect(sizeText(1), '1 byte');
    expect(sizeText(1023), '1023 bytes');
    expect(sizeText(1024), '1.0 KB');
    expect(sizeText(1500), '1.5 KB');
    expect(sizeText(20 * 1024), '20 KB');
    expect(sizeText(3 * 1024 * 1024 + 1024 * 200), '3.2 MB');
    expect(sizeText(5 * 1024 * 1024 * 1024), '5.0 GB');
  });
}
