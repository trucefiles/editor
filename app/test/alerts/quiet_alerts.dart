import 'package:flutter_riverpod/misc.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_editor/alerts/alert_tap.dart';
import 'package:truce_editor/platform/platform_wiring.dart';

/// Overrides that keep the system's notifications out of a test: no
/// alert is ever tapped, and the ringer keeps what it is told.
List<Override> quietAlerts([QuietRinger? ringer]) => [
  alertTapsProvider.overrideWithValue(const _NoTaps()),
  ringerProvider.overrideWithValue(ringer ?? QuietRinger()),
];

/// A ringer that only keeps what it was told, ringing nothing; it rings
/// while the app is closed if [ringsWhileClosed], as on Android.
final class QuietRinger implements Ringer {
  QuietRinger({this.ringsWhileClosed = false});

  @override
  final bool ringsWhileClosed;

  /// What it rings now, by number.
  final ringing = <int, PlannedAlert>{};

  /// The missed alerts it was told to show.
  final missed = <PlannedAlert>[];

  @override
  Stream<DateTime> get rang => const Stream.empty();

  @override
  Future<Set<int>> apply(List<RingChange> changes) async {
    for (final change in changes) {
      switch (change) {
        case Ring(:final number, :final alert):
          ringing[number] = alert;
        case Silence(:final number):
          ringing.remove(number);
      }
    }
    return const {};
  }

  @override
  Future<void> showMissed(List<PlannedAlert> missed) async =>
      this.missed.addAll(missed);
}

final class _NoTaps implements AlertTaps {
  const _NoTaps();

  @override
  Stream<AlertTap> get taps => const Stream.empty();

  @override
  Future<AlertTap?> launch() async => null;
}
