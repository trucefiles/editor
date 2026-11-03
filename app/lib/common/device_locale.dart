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
/// as `intl` has them: its own, else its language's, else English.
String dateLocaleOf(String locale) => Intl.verifiedLocale(
  locale,
  DateFormat.localeExists,
  onFailure: (_) => 'en',
)!;
