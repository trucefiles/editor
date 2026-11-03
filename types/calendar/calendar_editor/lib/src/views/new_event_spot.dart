/// Where the user asks for a new event in the calendar views.
sealed class NewEventSpot {
  const NewEventSpot();

  /// The day it starts on.
  DateTime get firstDay => switch (this) {
    AtTimes(:final start) => start,
    OnDays(:final first) => first,
    OnDay(:final day) => day,
  };

  /// The spot of a range the user dragged over, [start] up to [end] (on
  /// this device's clock): whole days are [OnDays]; else [AtTimes].
  factory NewEventSpot.of(DateTime start, DateTime end) =>
      _isMidnight(start) && _isMidnight(end) && end.isAfter(start)
      ? OnDays(start, end)
      : AtTimes(start, end);
}

/// From [start] up to [end]: a free time tapped or dragged over, or
/// where Add starts.
final class AtTimes extends NewEventSpot {
  const AtTimes(this.start, this.end);

  /// The hour a new event on [day] gets when the user picked no times:
  /// 9 to 10 on the wall clock (also on clock-change days).
  factory AtTimes.usualOn(DateTime day) => AtTimes(
    DateTime(day.year, day.month, day.day, 9),
    DateTime(day.year, day.month, day.day, 10),
  );

  final DateTime start;
  final DateTime end;
}

/// The whole days from [first] up to [end] (the day after the last): a
/// drag over days.
final class OnDays extends NewEventSpot {
  const OnDays(this.first, this.end);

  final DateTime first;
  final DateTime end;
}

/// On the day [day] falls on: a day tapped.
final class OnDay extends NewEventSpot {
  const OnDay(this.day);

  final DateTime day;
}

bool _isMidnight(DateTime time) =>
    time.hour == 0 && time.minute == 0 && time.second == 0;
