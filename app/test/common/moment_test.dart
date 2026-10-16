import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/moment.dart';

void main() {
  test('a later moment is after an earlier one', () {
    final earlier = Moment.now();
    final later = Moment.now();

    expect(earlier.isBefore(later), isTrue);
    expect(later.isBefore(earlier), isFalse);
    expect(earlier.isBefore(earlier), isFalse);
  });
}
