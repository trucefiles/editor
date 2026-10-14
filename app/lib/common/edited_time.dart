import 'package:flutter/material.dart';

/// When a file was last edited, as short as is clear on [now]'s day: the
/// time today, the day this year, else the date.
String editedTime(
  MaterialLocalizations local,
  DateTime time, {
  required DateTime now,
}) {
  final at = time.toLocal();
  final today = now.toLocal();
  if (DateUtils.isSameDay(at, today)) {
    return local.formatTimeOfDay(TimeOfDay.fromDateTime(at));
  }
  if (at.year == today.year) return local.formatShortMonthDay(at);
  return local.formatShortDate(at);
}
