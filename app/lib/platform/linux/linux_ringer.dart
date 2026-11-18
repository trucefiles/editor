import 'dart:async';

import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

import '../../alerts/alert_tap.dart';
import '../alert_notifications.dart' show missedNumberOf;
import 'desktop_notices.dart';

/// Rings alerts on the desktop while the app runs (window or tray): it
/// holds what it is handed and, at each whole minute of the app's clock
/// ([minutes]), shows each alert come as a desktop notification. After a
/// suspend the alerts that came meanwhile show at the next minute; an
/// event's that ended meanwhile is dropped. Nothing rings once the app
/// quits.
final class LinuxRinger implements Ringer {
  LinuxRinger(this._notices, {required Stream<DateTime> minutes}) {
    _minutes = minutes.listen((now) => unawaited(_check(now)));
  }

  final DesktopNotices _notices;
  final _held = <int, PlannedAlert>{};
  final _rang = StreamController<DateTime>.broadcast();
  late final StreamSubscription<DateTime> _minutes;

  @override
  bool get ringsWhileClosed => false;

  @override
  Stream<DateTime> get rang => _rang.stream;

  @override
  Future<Set<int>> apply(List<RingChange> changes) async {
    for (final change in changes) {
      switch (change) {
        case Ring(:final number, :final alert):
          _held[number] = alert;
        case Silence(:final number):
          _held.remove(number);
      }
    }
    // Held in memory: nothing is refused.
    return const {};
  }

  @override
  Future<void> showMissed(List<PlannedAlert> missed) async {
    for (final alert in missed) {
      await _notices.show(missedNumberOf(alert), alert, AlertShown.missed);
    }
  }

  /// Shows the alerts come by [now].
  Future<void> _check(DateTime now) async {
    final come = {
      for (final MapEntry(key: number, value: alert) in _held.entries)
        if (!alert.at.isAfter(now)) number: alert,
    };
    if (come.isEmpty) return;
    _held.removeWhere((number, _) => come.containsKey(number));
    for (final MapEntry(key: number, value: alert) in come.entries) {
      if (alert.relevantAt(now)) {
        await _notices.show(number, alert, AlertShown.notification);
      }
    }
    _rang.add(now);
  }

  Future<void> dispose() async {
    await _minutes.cancel();
    await _rang.close();
  }
}
