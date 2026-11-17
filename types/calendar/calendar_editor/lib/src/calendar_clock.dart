import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// The calendars' one clock, held by the app for its views and its
/// alerts: [today] on [now]'s clock and this device's time [zone], telling
/// its listeners when either changes. While it has listeners it checks at
/// each midnight, at least every minute (timers stop while the device
/// sleeps, so a midnight wake alone could come hours late) and whenever
/// the app returns to the front; no system tells the app of a zone
/// change. Without listeners it only answers when asked.
final class CalendarClock extends ChangeNotifier {
  /// [deviceZone] tells this device's time zone apart (by default as
  /// kalender does).
  CalendarClock(this._now, {this._deviceZone = deviceZoneNow});

  static const _every = Duration(minutes: 1);

  final DateTime Function() _now;
  final String Function() _deviceZone;

  /// Today and the zone as last checked, while it has listeners.
  ({DateTime today, String zone})? _checked;
  AppLifecycleListener? _resume;
  Timer? _wake;

  /// The time now.
  DateTime now() => _now();

  /// Today, at midnight.
  DateTime get today => (_checked ?? _fresh()).today;

  /// This device's time zone.
  String get zone => (_checked ?? _fresh()).zone;

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      _checked = _fresh();
      _resume = AppLifecycleListener(onResume: _check);
      _wakeNext();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  ({DateTime today, String zone}) _fresh() {
    final now = _now();
    return (today: DateTime(now.year, now.month, now.day), zone: _deviceZone());
  }

  /// Moves [today] and [zone] on if either changed since.
  void _check() {
    _wakeNext();
    final checked = _fresh();
    if (checked == _checked) return;
    _checked = checked;
    notifyListeners();
  }

  /// A wake at the next midnight or check, whichever comes first, to
  /// check again.
  void _wakeNext() {
    final now = _now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _wake?.cancel();
    _wake = Timer([midnight.difference(now), _every].min, _check);
  }

  void _stop() {
    _wake?.cancel();
    _resume?.dispose();
    _wake = null;
    _resume = null;
    _checked = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

/// This device's time zone now, as kalender tells it apart.
String deviceZoneNow() {
  final now = DateTime.now();
  return '${now.timeZoneName} ${now.timeZoneOffset}';
}
