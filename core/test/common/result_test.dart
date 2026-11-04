import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('map converts a value and keeps an error', () {
    expect((const Ok<int, String>(2).map((v) => v * 3) as Ok).value, 6);
    expect(
      (const Err<int, String>('gone').map((v) => v * 3) as Err).error,
      'gone',
    );
  });
}
