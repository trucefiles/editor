import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
}
