/// Where the user asks for a new event in the calendar views.
sealed class NewEventSpot {
  const NewEventSpot();

  /// The spot of a range the user tapped or dragged over, [start] up to
  /// [end] (on this device's clock): whole days are [OnDay], the first of
  /// them; else [AtTimes].
  factory NewEventSpot.of(DateTime start, DateTime end) =>
      _isMidnight(start) && _isMidnight(end) && end.isAfter(start)
      ? OnDay(start)
      : AtTimes(start, end);
}

/// From [start] up to [end]: a free time tapped or dragged over.
final class AtTimes extends NewEventSpot {
  const AtTimes(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// On the day [day] falls on: a day tapped, or Add event.
final class OnDay extends NewEventSpot {
  const OnDay(this.day);

  final DateTime day;
}

bool _isMidnight(DateTime time) =>
    time.hour == 0 && time.minute == 0 && time.second == 0;
