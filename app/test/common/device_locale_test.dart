import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:truce_editor/common/device_locale.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('date formats fall back to the language, then English', () {
    expect(dateLocaleOf('de_XX'), 'de');
    expect(dateLocaleOf('xx_XX'), 'en');
    expect(dateLocaleOf('de-CH'), 'de_CH');
  });

  test('English in a European region intl lacks reads as British English', () {
    expect(dateLocaleOf('en_DE'), 'en_GB');
    expect(dateLocaleOf('en-DK'), 'en_GB');
    expect(dateLocaleOf('en_150'), 'en_GB');
    expect(dateLocaleOf('en_Latn_DE'), 'en_GB');
    expect(dateLocaleOf('en_IE'), 'en_IE', reason: 'intl has it');
    expect(dateLocaleOf('en_JP'), 'en', reason: 'not in Europe');
    expect(dateLocaleOf('de_AT'), 'de_AT');
    expect(dateLocaleOf('xx_DE'), 'en', reason: 'not English');
    expect(
      supportedLocaleOf(const Locale('en', 'NL')),
      const Locale('en', 'GB'),
    );
  });

  test('a device locale without date formats becomes one with them', () {
    // intl reads C as English with ISO dates; numbers work for it too,
    // as the calendar's widgets need.
    final plain = supportedLocaleOf(const Locale('C'));
    expect(plain, const Locale('en', 'ISO'));
    expect(NumberFormat.decimalPattern(plain.toString()).format(7), '7');
    expect(supportedLocaleOf(const Locale('xx')), const Locale('en'));
    expect(supportedLocaleOf(const Locale('de', 'XX')), const Locale('de'));
    expect(
      supportedLocaleOf(const Locale('de', 'CH')),
      const Locale('de', 'CH'),
    );
    expect(
      supportedLocaleOf(
        const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
      ),
      const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
    );
  });
}
