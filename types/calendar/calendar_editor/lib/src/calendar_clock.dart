import 'dart:async';

import 'package:flutter/widgets.dart';

/// The calendars' one clock, held by the app for its views and its
/// alerts: [today] on [now]'s clock and this device's time [zone], telling
/// its listeners when either changes, and the time at each whole minute
/// ([minutes]). While it has listeners it checks at each whole minute
/// (timers stop while the device sleeps, so a wake set hours ahead could
/// come hours late) and whenever the app returns to the front; no system
/// tells the app of a zone change. Without listeners it only answers when
/// asked.
final class CalendarClock extends ChangeNotifier {
  /// [deviceZone] tells this device's time zone apart (by default as
  /// kalender does).
  CalendarClock(this._now, {this._deviceZone = deviceZoneNow});

  final DateTime Function() _now;
  final String Function() _deviceZone;

  /// Today and the zone as last checked, while it has listeners.
  ({DateTime today, String zone})? _checked;
  AppLifecycleListener? _resume;
  Timer? _wake;
  late final _minutes = StreamController<DateTime>.broadcast(
    onListen: _listened,
    onCancel: _unlistened,
  );

  /// The time at each whole minute, while listened to; after a sleep at
  /// the next whole minute. One wake serves it and the day and zone.
  Stream<DateTime> get minutes => _minutes.stream;

  /// The time now.
  DateTime now() => _now();

  /// Today, at midnight.
  DateTime get today => (_checked ?? _fresh()).today;

  /// This device's time zone.
  String get zone => (_checked ?? _fresh()).zone;

  /// Whether anyone listens, to the day and zone or to the minutes.
  bool get _anyListens => hasListeners || _minutes.hasListener;

  @override
  void addListener(VoidCallback listener) {
    _listened();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _unlistened();
  }

  /// Starts checking as the first listener comes.
  void _listened() {
    if (_wake != null) return;
    _checked = _fresh();
    _resume = AppLifecycleListener(onResume: _check);
    _wakeNext();
  }

  /// Stops checking once the last listener left.
  void _unlistened() {
    if (!_anyListens) _stop();
  }

  ({DateTime today, String zone}) _fresh() {
    final now = _now();
    return (today: DateTime(now.year, now.month, now.day), zone: _deviceZone());
  }

  /// Tells the minute, and moves [today] and [zone] on if either changed
  /// since.
  void _check() {
    _wakeNext();
    if (_minutes.hasListener) _minutes.add(_now());
    final checked = _fresh();
    if (checked == _checked) return;
    _checked = checked;
    notifyListeners();
  }

  /// A wake at the next whole minute (midnight is one), to check again.
  void _wakeNext() {
    final now = _now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _wake?.cancel();
    _wake = Timer(next.difference(now), _check);
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
    unawaited(_minutes.close());
    super.dispose();
  }
}

/// This device's time zone now, as kalender tells it apart.
String deviceZoneNow() {
  final now = DateTime.now();
  return '${now.timeZoneName} ${now.timeZoneOffset}';
}
