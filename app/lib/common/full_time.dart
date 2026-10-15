import 'package:flutter/material.dart';

/// [time] with its full date and clock time, in local time.
String fullTime(MaterialLocalizations local, DateTime time) {
  final at = time.toLocal();
  final date = local.formatFullDate(at);
  final clock = local.formatTimeOfDay(TimeOfDay.fromDateTime(at));
  return '$date, $clock';
}
