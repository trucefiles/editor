import 'dart:async';

import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

import '../../alerts/alert_tap.dart';
import '../alert_notifications.dart' show missedNumberOf;
import 'desktop_notices.dart';

/// Rings alerts on the desktop while the app runs (window or tray): it
/// holds what it is handed and checks the wall clock once a minute, on
/// the minute, showing each alert come as a desktop notification. Timers
/// sleep with the computer, so after a suspend the alerts that came
/// meanwhile show within a minute; an event's that ended meanwhile is
/// dropped. Nothing rings once the app quits.
final class LinuxRinger implements Ringer {
  LinuxRinger(this._notices, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _wakeNext();
  }

  final DesktopNotices _notices;
  final DateTime Function() _now;
  final _held = <int, PlannedAlert>{};
  final _rang = StreamController<DateTime>.broadcast();
  Timer? _wake;

  @override
  bool get ringsWhileClosed => false;

  @override
  Stream<DateTime> get rang => _rang.stream;

  @override
  Future<void> apply(List<RingChange> changes) async {
    for (final change in changes) {
      switch (change) {
        case Ring(:final number, :final alert):
          _held[number] = alert;
        case Silence(:final number):
          _held.remove(number);
      }
    }
  }

  @override
  Future<void> showMissed(List<PlannedAlert> missed) async {
    for (final alert in missed) {
      await _notices.show(missedNumberOf(alert), alert, AlertShown.missed);
    }
  }

  /// Shows the alerts come by now, and wakes again on the next minute.
  Future<void> _check() async {
    _wakeNext();
    final now = _now();
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

  /// A wake on the next minute of the wall clock.
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
    _wake = Timer(next.difference(now), () => unawaited(_check()));
  }

  Future<void> dispose() async {
    _wake?.cancel();
    await _rang.close();
  }
}
