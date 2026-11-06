import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  test('names a few, then counts the rest', () {
    expect(fewNamed(const ['Dentist']), '"Dentist"');
    expect(fewNamed(const ['A', 'B', 'C']), '"A", "B", "C"');
    expect(
      fewNamed(const ['A', 'B', 'C', 'D', 'E']),
      '"A", "B", "C" and 2 more',
    );
  });
}
