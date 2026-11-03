import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';
import 'device_locale.dart';

/// The device's time texts, read once at start: the one source for
/// every date and time the app writes itself, on cards and on screens
/// alike (Flutter's own, e.g. in date pickers, follow the same locale,
/// see [appLocalizations]).
final timeTextsProvider = Provider<TimeTexts>(
  (ref) => TimeTexts(
    locale: ref.watch(deviceLocaleProvider).toString(),
    use24Hour: PlatformDispatcher.instance.alwaysUse24HourFormat,
  ),
);

/// Dates and times as the system shows them: in the formats of its
/// [locale] (e.g. `de_DE`), with a 24-hour clock where the system is set
/// to one ([use24Hour]) or its locale uses one. Locales without date
/// formats fall back to English.
final class TimeTexts {
  TimeTexts({required String locale, required this.use24Hour})
    : locale = dateLocaleOf(locale);

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

  /// When something on a calendar starts: its weekday and day, and its
  /// clock time unless it lasts [allDay].
  String day(DateTime start, {required bool allDay}) {
    final date = DateFormat.MMMEd(locale).format(start);
    return allDay ? date : '$date, ${_clock(start)}';
  }

  String _clock(DateTime at) =>
      (use24Hour ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(at);
}
