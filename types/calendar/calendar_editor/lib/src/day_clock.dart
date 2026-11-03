import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Today on [now]'s clock, moving on with the day (and telling its
/// listeners then): the one day tick of the calendar views. It checks
/// the day at each midnight and at least every minute, since timers
/// stop while the device sleeps and a midnight wake alone could come
/// hours late.
final class DayClock extends ChangeNotifier {
  DayClock(this._now) {
    _today = _nextToday();
  }

  static const _check = Duration(minutes: 1);

  final DateTime Function() _now;
  late DateTime _today;
  Timer? _wake;

  /// Today, at midnight.
  DateTime get today => _today;

  /// Moves [today] on if the day changed since.
  void _moveOn() {
    final today = _nextToday();
    if (today == _today) return;
    _today = today;
    notifyListeners();
  }

  /// Today, and a wake at the next midnight or check, whichever comes
  /// first, to move it on.
  DateTime _nextToday() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final midnight = DateTime(today.year, today.month, today.day + 1);
    _wake?.cancel();
    _wake = Timer([midnight.difference(now), _check].min, _moveOn);
    return today;
  }

  @override
  void dispose() {
    _wake?.cancel();
    super.dispose();
  }
}
