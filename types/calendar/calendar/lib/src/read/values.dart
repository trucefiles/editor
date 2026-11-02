/// How the values of the properties the app reads and writes are written
/// (RFC 5545, 3.3): times, days and durations. The one owner of their
/// formats; edits and the reader both use it.
library;

import '../model/calendar_time.dart';
import 'content_line.dart';

/// The time in [line] (e.g. `DTSTART`); `null` if it can't be read.
CalendarTime? timeOf(ContentLine line) {
  final value = line.value.trim();
  final zone = line.param('TZID');
  if (line.param('VALUE') == 'DATE' || value.length == 8) {
    return switch (_day(value)) {
      final day? => AllDay(day),
      null => null,
    };
  }
  final utc = value.endsWith('Z');
  final wall = _dateTime(utc ? value.substring(0, value.length - 1) : value);
  if (wall == null) return null;
  return switch ((utc, zone)) {
    (true, _) => UtcTime(wall),
    (false, final zone?) => Zoned(zone, wall),
    (false, null) => Floating(wall),
  };
}

/// The times in [line] (e.g. `EXDATE`, which may list several).
List<CalendarTime> timesOf(ContentLine line) => [
  for (final value in line.value.split(','))
    ?timeOf(ContentLine(line.name, value, params: line.params)),
];

/// [name] holding [time], as the file writes it.
ContentLine timeLine(String name, CalendarTime time) => switch (time) {
  AllDay(:final wall) => ContentLine(
    name,
    dayText(wall),
    params: const {'VALUE': 'DATE'},
  ),
  Floating(:final wall) => ContentLine(name, _dateTimeText(wall)),
  UtcTime(:final wall) => ContentLine(name, '${_dateTimeText(wall)}Z'),
  Zoned(:final zone, :final wall) => ContentLine(
    name,
    _dateTimeText(wall),
    params: {'TZID': zone},
  ),
};

/// [name] holding [times], all of one kind.
ContentLine timesLine(String name, List<CalendarTime> times) {
  final lines = [for (final time in times) timeLine(name, time)];
  return ContentLine(
    name,
    lines.map((line) => line.value).join(','),
    params: lines.first.params,
  );
}

/// [name] holding [text] as a TEXT value.
ContentLine textLine(String name, String text) =>
    ContentLine(name, escapeText(text));

/// [moment] in UTC, as `DTSTAMP` and `LAST-MODIFIED` hold it.
ContentLine stampLine(String name, DateTime moment) =>
    ContentLine(name, '${_dateTimeText(moment.toUtc())}Z');

/// The day [wall] as written (`20261101`).
String dayText(DateTime wall) =>
    '${_digits(wall.year, 4)}${_digits(wall.month, 2)}${_digits(wall.day, 2)}';

String _dateTimeText(DateTime wall) =>
    '${dayText(wall)}T${_digits(wall.hour, 2)}${_digits(wall.minute, 2)}'
    '${_digits(wall.second, 2)}';

String _digits(int value, int width) => '$value'.padLeft(width, '0');

DateTime? _day(String value) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final [year, month, day] = [
    for (final group in [1, 2, 3]) int.parse(match[group]!),
  ];
  return DateTime.utc(year, month, day);
}

DateTime? _dateTime(String value) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$')
      .firstMatch(value);
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (final group in [1, 2, 3, 4, 5, 6]) int.parse(match[group]!),
  ];
  return DateTime.utc(year, month, day, hour, minute, second);
}

/// The duration [value] (`P1D`, `-PT15M`); `null` if it can't be read.
Duration? durationOf(String value) {
  final match = RegExp(
    r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
  ).firstMatch(value.trim());
  if (match == null || value.trim().length < 2) return null;
  int part(int group) => int.tryParse(match[group] ?? '') ?? 0;
  final duration = Duration(
    days: part(2) * 7 + part(3),
    hours: part(4),
    minutes: part(5),
    seconds: part(6),
  );
  return match[1] == '-' ? -duration : duration;
}

/// [duration] as written (`-PT15M`).
String durationText(Duration duration) {
  final sign = duration.isNegative ? '-' : '';
  final whole = duration.abs();
  final days = whole.inDays;
  final hours = whole.inHours % 24;
  final minutes = whole.inMinutes % 60;
  final seconds = whole.inSeconds % 60;
  final time = [
    if (hours > 0) '${hours}H',
    if (minutes > 0) '${minutes}M',
    if (seconds > 0) '${seconds}S',
  ].join();
  return [
    '${sign}P',
    if (days > 0) '${days}D',
    if (time.isNotEmpty) 'T$time',
    if (days == 0 && time.isEmpty) 'T0S',
  ].join();
}
