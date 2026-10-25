import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('a later moment is after an earlier one', () {
    final earlier = Moment.now();
    final later = Moment.now();

    expect(earlier.isBefore(later), isTrue);
    expect(later.isBefore(earlier), isFalse);
    expect(earlier.isBefore(earlier), isFalse);
  });
}
