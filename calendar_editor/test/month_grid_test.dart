import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

void main() {
  test('a month grid shows whole weeks from the first weekday', () {
    // November 2026 starts on a Sunday and ends on a Monday.
    final november = DateTime(2026, 11);
    expect(gridDays(november, DateTime.sunday % 7), (
      first: DateTime(2026, 11, 1),
      end: DateTime(2026, 12, 6),
    ));
    expect(gridDays(november, DateTime.monday), (
      first: DateTime(2026, 10, 26),
      end: DateTime(2026, 12, 7),
    ));
  });
}
