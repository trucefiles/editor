import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_editor/common/app_localizations.dart';

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

  testWidgets("times use the locale's clock", (tester) async {
    final german = await wordsFor(tester, const Locale('de', 'DE'));
    expect(german.timeOfDayFormat(), TimeOfDayFormat.HH_colon_mm);
    expect(
      german.formatTimeOfDay(const TimeOfDay(hour: 14, minute: 5)),
      '14:05',
    );

    final american = await wordsFor(tester, const Locale('en', 'US'));
    expect(american.timeOfDayFormat(), TimeOfDayFormat.h_colon_mm_space_a);
    expect(
      american.timeOfDayFormat(alwaysUse24HourFormat: true),
      TimeOfDayFormat.HH_colon_mm,
    );
  });
}
