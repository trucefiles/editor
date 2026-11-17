import 'dart:convert';

import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

/// Where the alerts the user taps come from: the system's notifications.
abstract interface class AlertTaps {
  /// The alerts the user taps while the app runs.
  Stream<AlertTap> get taps;

  /// The alert whose tap started the app; `null` if none did.
  Future<AlertTap?> launch();
}

/// How an alert's notification was shown.
enum AlertShown {
  /// As a notification that pops up.
  notification,

  /// As an alarm, ringing until dismissed or snoozed.
  alarm,

  /// Quietly, as missed.
  missed,
}

/// An alert's notification as the system hands it back when the user
/// taps it or one of its buttons: what it shows, as [shown], under its
/// [number].
final class AlertTap {
  const AlertTap(this.alert, {required this.number, required this.shown});

  final PlannedAlert alert;
  final int number;
  final AlertShown shown;

  /// What a notification carries, to come back as this.
  String get payload => jsonEncode({
    'number': number,
    'shown': shown.name,
    'alert': alert.toJson(),
  });

  /// The tap [payload] stands for; `null` if it is none of ours.
  static AlertTap? fromPayload(String? payload) {
    if (payload == null) return null;
    final Object? json;
    try {
      json = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (json case {
      'number': final int number,
      'shown': final String shown,
      'alert': final Object? alert,
    }) {
      final (planned, how) = (
        PlannedAlert.fromJson(alert),
        AlertShown.values.asNameMap()[shown],
      );
      if (planned != null && how != null) {
        return AlertTap(planned, number: number, shown: how);
      }
    }
    return null;
  }
}
