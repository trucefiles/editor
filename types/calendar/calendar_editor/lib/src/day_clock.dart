import 'dart:async';

import 'package:flutter/foundation.dart';

/// Today on [now]'s clock, moving on at each midnight (and telling its
/// listeners then): the one day tick of the calendar views.
final class DayClock extends ChangeNotifier {
  DayClock(this._now) {
    _today = _nextToday();
  }

  final DateTime Function() _now;
  late DateTime _today;
  Timer? _midnight;

  /// Today, at midnight.
  DateTime get today => _today;

  /// Today, and a wake at the next midnight to move it on.
  DateTime _nextToday() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    _midnight?.cancel();
    _midnight = Timer(
      DateTime(today.year, today.month, today.day + 1).difference(now),
      () {
        _today = _nextToday();
        notifyListeners();
      },
    );
    return today;
  }

  @override
  void dispose() {
    _midnight?.cancel();
    super.dispose();
  }
}
