import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_editor/common/time_texts.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final now = DateTime(2026, 10, 14, 18);

  String edited(DateTime time, {String locale = 'en_US', bool h24 = false}) =>
      TimeTexts(locale: locale, use24Hour: h24).edited(time, now: now);

  test('shows the time for today', () {
    expect(edited(DateTime(2026, 10, 14, 9, 5)), '9:05 AM');
  });

  test('shows the day for this year', () {
    expect(edited(DateTime(2026, 10, 13, 23)), 'Oct 13');
  });

  test('shows the date for other years', () {
    expect(edited(DateTime(2025, 10, 14, 9)), 'Oct 14, 2025');
  });

  test("follows the locale's formats", () {
    expect(edited(DateTime(2026, 10, 14, 21, 5), locale: 'de-DE'), '21:05');
    expect(edited(DateTime(2026, 10, 13, 23), locale: 'de-DE'), '13. Okt.');
    expect(edited(DateTime(2025, 10, 14, 9), locale: 'de-DE'), '14. Okt. 2025');
  });

  test('uses a 24-hour clock where the system is set to one', () {
    expect(edited(DateTime(2026, 10, 14, 21, 5), h24: true), '21:05');
  });

  test('falls back to English for a locale without date formats', () {
    expect(edited(DateTime(2026, 10, 13, 23), locale: 'xx-XX'), 'Oct 13');
  });

  test('full time has the weekday, date and clock time', () {
    expect(
      TimeTexts(
        locale: 'en_US',
        use24Hour: true,
      ).full(DateTime(2026, 10, 14, 9, 5)),
      'Wednesday, October 14, 2026, 09:05',
    );
  });
}
