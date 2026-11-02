import 'package:truce_calendar/truce_calendar.dart';

/// Where [cycle] is on [today], in words: the day of the cycle and when
/// the next period likely starts.
String cycleText(CyclePrediction cycle, DateTime today) {
  final until = cycle.daysUntilNext(today);
  return [
    'Day ${cycle.dayOfCycle(today)} of the cycle',
    switch (until) {
      0 => 'next period likely today',
      1 => 'next period in about 1 day',
      > 1 => 'next period in about $until days',
      _ => 'next period ${-until} days later than guessed',
    },
  ].join(' · ');
}
