import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dates and times as the system shows them: in the formats of its
/// [locale] (e.g. `de_DE`), with a 24-hour clock where the system is set
/// to one ([use24Hour]) or its locale uses one. Locales without date
/// formats fall back to English.
final class TimeTexts {
  TimeTexts({required String locale, required this.use24Hour})
    : locale = Intl.verifiedLocale(
        locale,
        DateFormat.localeExists,
        onFailure: (_) => 'en',
      )!;

  /// The texts for [context]: the system's locale and clock.
  factory TimeTexts.of(BuildContext context) => TimeTexts(
    locale: View.of(context).platformDispatcher.locale.toLanguageTag(),
    use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  final String locale;
  final bool use24Hour;

  /// When a file was last edited, as short as is clear on [now]'s day:
  /// the time today, the day this year, else the date.
  String edited(DateTime time, {required DateTime now}) {
    final at = time.toLocal();
    final today = now.toLocal();
    if (DateUtils.isSameDay(at, today)) return _clock(at);
    if (at.year == today.year) return DateFormat.MMMd(locale).format(at);
    return DateFormat.yMMMd(locale).format(at);
  }

  /// [time] with its full date and clock time, in local time.
  String full(DateTime time) {
    final at = time.toLocal();
    return '${DateFormat.yMMMMEEEEd(locale).format(at)}, ${_clock(at)}';
  }

  String _clock(DateTime at) =>
      (use24Hour ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(at);
}
