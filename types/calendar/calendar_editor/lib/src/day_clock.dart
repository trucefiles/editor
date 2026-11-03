import 'dart:async';

import 'package:flutter/widgets.dart';

/// Today on [now]'s clock, moving on at each midnight (and telling its
/// listeners then): the one day tick of the calendar views.
final class DayClock extends ChangeNotifier {
  DayClock(this._now) {
    _today = _nextToday();
    // Timers stop while the device sleeps, so the midnight wake can come
    // hours late: the day is checked again when the app comes back.
    _resumes = AppLifecycleListener(onResume: _moveOn);
  }

  final DateTime Function() _now;
  late DateTime _today;
  Timer? _midnight;
  late final AppLifecycleListener _resumes;

  /// Today, at midnight.
  DateTime get today => _today;

  /// Moves [today] on if the day changed since.
  void _moveOn() {
    final today = _nextToday();
    if (today == _today) return;
    _today = today;
    notifyListeners();
  }

  /// Today, and a wake at the next midnight to move it on.
  DateTime _nextToday() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    _midnight?.cancel();
    _midnight = Timer(
      DateTime(today.year, today.month, today.day + 1).difference(now),
      _moveOn,
    );
    return today;
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _resumes.dispose();
    super.dispose();
  }
}
