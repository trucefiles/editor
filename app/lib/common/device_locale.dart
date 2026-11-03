import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The device's language and region, read once at start: the one source
/// of how dates, times and the first day of the week look in the app.
final deviceLocaleProvider = Provider<Locale>(
  (_) => supportedLocaleOf(PlatformDispatcher.instance.locale),
);

/// [device] as a locale the app has date formats for: itself, else its
/// language, else English. A device set to a locale without formats
/// (e.g. `C` on Linux) still gets one the app and its widgets can use.
Locale supportedLocaleOf(Locale device) =>
    switch (dateLocaleOf(device.toString()).split('_')) {
      [final language, final script] when script.length == 4 =>
        Locale.fromSubtags(languageCode: language, scriptCode: script),
      [final language, final country] => Locale(language, country),
      final parts => Locale(parts.first),
    };

/// The name of the date formats for [locale] (e.g. `de_CH` or `de-CH`),
/// as `intl` has them: its own, else its language's, else English.
String dateLocaleOf(String locale) => Intl.verifiedLocale(
  locale,
  DateFormat.localeExists,
  onFailure: (_) => 'en',
)!;

/// The app's localizations for any locale: Flutter's own English texts,
/// with the locale's date formats and first day of the week. The app is
/// in English only, so the words never follow the locale.
const appLocalizations = <LocalizationsDelegate<Object?>>[
  _EnglishMaterialDelegate(),
  _EnglishCupertinoDelegate(),
  DefaultWidgetsLocalizations.delegate,
];

final class _EnglishMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _EnglishMaterialDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final name = dateLocaleOf(locale.toString());
    return SynchronousFuture(
      MaterialLocalizationEn(
        localeName: name,
        fullYearFormat: DateFormat.y(name),
        compactDateFormat: DateFormat.yMd(name),
        shortDateFormat: DateFormat.yMMMd(name),
        mediumDateFormat: DateFormat.MMMEd(name),
        longDateFormat: DateFormat.yMMMMEEEEd(name),
        yearMonthFormat: DateFormat.yMMMM(name),
        shortMonthDayFormat: DateFormat.MMMd(name),
        decimalFormat: NumberFormat.decimalPattern(name),
        twoDigitZeroPaddedFormat: NumberFormat('00', name),
      ),
    );
  }

  @override
  bool shouldReload(_EnglishMaterialDelegate old) => false;
}

/// Flutter's English Cupertino texts for any locale; the app shows no
/// Cupertino dates.
final class _EnglishCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _EnglishCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_EnglishCupertinoDelegate old) => false;
}
