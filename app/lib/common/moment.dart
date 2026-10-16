/// A point in the order of events within this run of the app: a later
/// [Moment.now] is always after an earlier one, whatever the wall clock
/// does (e.g. it is set back). Never stored: it means nothing in the next
/// run.
final class Moment {
  Moment.now() : _tick = ++_lastTick;

  static int _lastTick = 0;

  final int _tick;

  bool isBefore(Moment other) => _tick < other._tick;
}
