import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// The calendar views' one clock: [today] on [now]'s clock and this
/// device's time [zone], telling its listeners when either changes. It
/// checks at each midnight, at least every minute (timers stop while the
/// device sleeps, so a midnight wake alone could come hours late) and
/// whenever the app returns to the front; no system tells the app of a
/// zone change.
final class ViewsClock extends ChangeNotifier {
  /// [deviceZone] tells this device's time zone apart (by default as
  /// kalender does).
  ViewsClock(this._now, {this._deviceZone = deviceZoneNow}) {
    _zone = _deviceZone();
    _today = _nextToday();
    _resume = AppLifecycleListener(onResume: _check);
  }

  static const _every = Duration(minutes: 1);

  final DateTime Function() _now;
  final String Function() _deviceZone;
  late DateTime _today;
  late String _zone;
  late final AppLifecycleListener _resume;
  Timer? _wake;

  /// Today, at midnight.
  DateTime get today => _today;

  /// This device's time zone.
  String get zone => _zone;

  /// Moves [today] and [zone] on if either changed since.
  void _check() {
    final (today, zone) = (_nextToday(), _deviceZone());
    if (today == _today && zone == _zone) return;
    _today = today;
    _zone = zone;
    notifyListeners();
  }

  /// Today, and a wake at the next midnight or check, whichever comes
  /// first, to check again.
  DateTime _nextToday() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final midnight = DateTime(today.year, today.month, today.day + 1);
    _wake?.cancel();
    _wake = Timer([midnight.difference(now), _every].min, _check);
    return today;
  }

  @override
  void dispose() {
    _wake?.cancel();
    _resume.dispose();
    super.dispose();
  }
}

/// This device's time zone now, as kalender tells it apart.
String deviceZoneNow() {
  final now = DateTime.now();
  return '${now.timeZoneName} ${now.timeZoneOffset}';
}
