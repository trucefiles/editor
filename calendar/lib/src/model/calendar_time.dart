import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// When an event starts or ends, as its file says: a day, or a time of
/// day in one of three ways. Times of day are wall clocks: their fields
/// as written, held in a UTC [DateTime] only so no zone moves them.
sealed class CalendarTime {
  const CalendarTime();

  /// The wall clock (or the day at midnight) as written.
  DateTime get wall;

  /// When it is on this device's clock.
  DateTime get local;

  /// The same kind of time with [wall] instead (e.g. one occurrence of a
  /// repeating event).
  CalendarTime at(DateTime wall);
}

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
  bool operator ==(Object other) => other is AllDay && other.wall == wall;

  @override
  int get hashCode => wall.hashCode;
}

/// A time of day wherever the device is (no zone): new events are
/// written so.
final class Floating extends CalendarTime {
  Floating(DateTime wall) : wall = _asWall(wall);

  @override
  final DateTime wall;

  @override
  DateTime get local => _localOf(wall);

  @override
  Floating at(DateTime wall) => Floating(wall);

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
  UtcTime at(DateTime wall) => UtcTime(wall);

  @override
  bool operator ==(Object other) => other is UtcTime && other.wall == wall;

  @override
  int get hashCode => wall.hashCode;
}

/// A time of day in the time zone [zone] (an IANA name). A zone the app
/// doesn't know (e.g. a Windows name) reads as floating.
final class Zoned extends CalendarTime {
  Zoned(this.zone, DateTime wall) : wall = _asWall(wall);

  final String zone;

  @override
  final DateTime wall;

  @override
  DateTime get local => switch (_location(zone)) {
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

/// The time zone database, loaded once when first needed: the
/// `timezone` package keeps it in one place for the whole program.
bool _zonesLoaded = false;

tz.Location? _location(String zone) {
  if (!_zonesLoaded) {
    zones.initializeTimeZones();
    _zonesLoaded = true;
  }
  return tz.timeZoneDatabase.locations[zone];
}
