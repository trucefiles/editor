import 'calendar_time.dart';

/// The wall clock of [time], a date of a series (its end, `UNTIL`, or an
/// extra date, `RDATE`), on the clock of the series' [start]: for a day
/// start, the written day (days have no zone); for a time-of-day start,
/// the end of a written day (as an end means), a floating time as
/// written, and a UTC or zoned time on [start]'s own clock.
DateTime wallOn(CalendarTime start, CalendarTime time) {
  final wall = time.wall;
  return switch ((start, time)) {
    (AllDay(), _) => DateTime.utc(wall.year, wall.month, wall.day),
    (_, AllDay()) => DateTime.utc(wall.year, wall.month, wall.day, 23, 59, 59),
    (_, Floating()) => wall,
    _ => start.sameKindAt(time.local).wall,
  };
}
