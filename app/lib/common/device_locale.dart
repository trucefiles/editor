import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
/// as `intl` has them: its own, else the closest one. As in the Unicode
/// locale data (CLDR), English in a European region intl lacks reads as
/// British English (day before month, 24-hour clock, weeks from Monday);
/// any other locale falls back to its language, else to English.
String dateLocaleOf(String locale) => switch (Intl.verifiedLocale(
  locale,
  DateFormat.localeExists,
  onFailure: (_) => 'en',
)!) {
  'en' when _isEnglishInEurope(locale) => 'en_GB',
  final found => found,
};

bool _isEnglishInEurope(String locale) =>
    switch (Intl.canonicalizedLocale(locale).split('_')) {
      ['en', ..., final region] => _europe.contains(region),
      _ => false,
    };

/// The regions of Europe, and Europe itself (`150`), as locales name them.
final _europe =
    ('150 AD AL AT AX BA BE BG BY CH CY CZ DE DK EE ES FI FO FR GB GG GI GR '
            'HR HU IE IM IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT RO RS '
            'RU SE SI SJ SK SM UA VA XK')
        .split(' ')
        .toSet();
