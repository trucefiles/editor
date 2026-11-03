import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'device_locale.dart';

/// The app's localizations for any locale: Flutter's own English texts,
/// with the locale's date formats, clock and first day of the week. The app is
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
      _EnglishWithLocaleClock(
        uses24Hour: RegExp('[Hk]').hasMatch(DateFormat.jm(name).pattern!),
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

/// Flutter's English texts, with a 24-hour clock where the locale
/// [uses24Hour] (e.g. in time pickers), as the system setting also asks.
final class _EnglishWithLocaleClock extends MaterialLocalizationEn {
  const _EnglishWithLocaleClock({
    required this.uses24Hour,
    required super.localeName,
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  final bool uses24Hour;

  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      super.timeOfDayFormat(
        alwaysUse24HourFormat: alwaysUse24HourFormat || uses24Hour,
      );
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
