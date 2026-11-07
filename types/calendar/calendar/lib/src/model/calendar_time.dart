import 'package:timezone/timezone.dart' as tz;

import 'time_zones.dart';

/// When an event starts or ends, as its file says: a day, or a time of
/// day in one of three ways. Times of day are wall clocks: their fields
/// as written, held in a UTC [DateTime] only so no zone moves them.
sealed class CalendarTime {
  const CalendarTime();

  /// The wall clock (or the day at midnight) as written.
  DateTime get wall;

  /// The time zone it is in (an IANA name, or one the app doesn't know);
  /// `null` for a day, a floating time or UTC.
  String? get zone => null;

  /// When it is on this device's clock.
  DateTime get local;

  /// The wall clock a person edits it on: [wall], but a UTC moment on
  /// this device's clock, as UTC is no place a person knows.
  DateTime get editWall => wall;

  /// The same kind of time with [wall] instead (e.g. one occurrence of a
  /// repeating event).
  CalendarTime at(DateTime wall);

  /// The same kind of time at the moment [moment] (e.g. where a drag let
  /// go): an event in New York moved in Berlin stays in New York. A day
  /// becomes the day [moment] falls on, on this device's clock.
  CalendarTime sameKindAt(DateTime moment);
}

/// The time a new or changed event gets at [wall] (a wall clock as a
/// person edits it, see [CalendarTime.editWall]): a day if [allDay]; else
/// of [was]'s kind if that is a time of day, so an event keeps its zone;
/// else in [deviceZone], this device's time zone, if the app knows it,
/// else floating.
CalendarTime timeAt(
  DateTime wall, {
  required bool allDay,
  CalendarTime? was,
  String? deviceZone,
}) => switch ((allDay, was, deviceZone)) {
  (true, _, _) => AllDay(wall),
  (false, UtcTime(), _) => UtcTime(_localOf(wall).toUtc()),
  (false, final was?, _) when was is! AllDay => was.at(wall),
  (false, _, final zone?) when locationOf(zone) != null => Zoned(zone, wall),
  _ => Floating(wall),
};

/// A whole day.
final class AllDay extends CalendarTime {
  AllDay(DateTime day) : wall = DateTime.utc(day.year, day.month, day.day);

  @override
  final DateTime wall;

  @override
  DateTime get local => DateTime(wall.year, wall.month, wall.day);

  @override
  AllDay at(DateTime wall) => AllDay(wall);

  @override
  AllDay sameKindAt(DateTime moment) => AllDay(moment.toLocal());

  @override
  bool operator ==(Object other) => other is AllDay && other.wall == wall;

  @override
  int get hashCode => wall.hashCode;
}

/// A time of day wherever the device is (no zone).
final class Floating extends CalendarTime {
  Floating(DateTime wall) : wall = _asWall(wall);

  @override
  final DateTime wall;

  @override
  DateTime get local => _localOf(wall);

  @override
  Floating at(DateTime wall) => Floating(wall);

  @override
  Floating sameKindAt(DateTime moment) => Floating(moment.toLocal());

  @override
  bool operator ==(Object other) => other is Floating && other.wall == wall;

  @override
  int get hashCode => wall.hashCode;
}

/// A moment in UTC.
final class UtcTime extends CalendarTime {
  UtcTime(DateTime wall) : wall = _asWall(wall);

  @override
  final DateTime wall;

  @override
  DateTime get local => wall.toLocal();

  @override
  DateTime get editWall => _asWall(local);

  @override
  UtcTime at(DateTime wall) => UtcTime(wall);

  @override
  UtcTime sameKindAt(DateTime moment) => UtcTime(moment.toUtc());

  @override
  bool operator ==(Object other) => other is UtcTime && other.wall == wall;

  @override
  int get hashCode => wall.hashCode;
}

/// A time of day in the time zone [zone] (an IANA name). A zone the app
/// doesn't know (e.g. a Windows name) reads as floating.
final class Zoned extends CalendarTime {
  Zoned(this.zone, DateTime wall) : wall = _asWall(wall);

  @override
  final String zone;

  @override
  final DateTime wall;

  @override
  DateTime get local => switch (locationOf(zone)) {
    final location? => DateTime.fromMillisecondsSinceEpoch(
      tz.TZDateTime(
        location,
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
        wall.second,
      ).millisecondsSinceEpoch,
    ),
    null => _localOf(wall),
  };

  @override
  Zoned at(DateTime wall) => Zoned(zone, wall);

  @override
  Zoned sameKindAt(DateTime moment) => switch (locationOf(zone)) {
    final location? => Zoned(zone, tz.TZDateTime.from(moment, location)),
    null => Zoned(zone, moment.toLocal()),
  };

  @override
  bool operator ==(Object other) =>
      other is Zoned && other.zone == zone && other.wall == wall;

  @override
  int get hashCode => Object.hash(zone, wall);
}

/// [time]'s fields as a wall clock.
DateTime _asWall(DateTime time) => DateTime.utc(
  time.year,
  time.month,
  time.day,
  time.hour,
  time.minute,
  time.second,
);

DateTime _localOf(DateTime wall) => DateTime(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
  wall.second,
);
