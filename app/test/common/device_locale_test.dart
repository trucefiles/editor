import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:truce_editor/common/device_locale.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<MaterialLocalizations> wordsFor(
    WidgetTester tester,
    Locale locale,
  ) async {
    late MaterialLocalizations words;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: [locale],
        localizationsDelegates: appLocalizations,
        home: Builder(
          builder: (context) {
            words = MaterialLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return words;
  }

  testWidgets("the week starts on the region's first day, in English "
      'words', (tester) async {
    final swiss = await wordsFor(tester, const Locale('de', 'CH'));
    expect(swiss.firstDayOfWeekIndex, 1);
    expect(swiss.cancelButtonLabel, 'Cancel');
    expect(swiss.formatMediumDate(DateTime(2026, 11, 3)), 'Di., 3. Nov.');

    final american = await wordsFor(tester, const Locale('en', 'US'));
    expect(american.firstDayOfWeekIndex, 0);
  });

  test('date formats fall back to the language, then English', () {
    expect(dateLocaleOf('de_XX'), 'de');
    expect(dateLocaleOf('xx_XX'), 'en');
    expect(dateLocaleOf('de-CH'), 'de_CH');
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
