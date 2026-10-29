import 'package:flutter/foundation.dart';

/// How changes made outside the app (by the sync tool, other apps) show up
/// while it is open.
enum RefreshMode {
  /// As they happen where possible; elsewhere as the sync tool decides.
  live,

  /// By checking the folders every [RefreshSettings.interval].
  periodic,

  /// Only when the user refreshes (or opens a document, comes back to the app).
  manual,
}

/// The user's refresh setting, per device.
@immutable
final class RefreshSettings {
  const RefreshSettings({required this.mode, required this.interval});

  /// Live, checking every 10 seconds where live updates aren't possible.
  static const standard = RefreshSettings(
    mode: RefreshMode.live,
    interval: Duration(seconds: 10),
  );

  /// The intervals the user can pick from.
  static const intervals = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  final RefreshMode mode;

  /// How often folders are checked for changes when they are polled.
  final Duration interval;

  RefreshSettings copyWith({RefreshMode? mode, Duration? interval}) =>
      RefreshSettings(
        mode: mode ?? this.mode,
        interval: interval ?? this.interval,
      );

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'intervalSeconds': interval.inSeconds,
  };

  /// `null` if [json] is not a setting written by [toJson], or names an
  /// interval the user can't pick.
  static RefreshSettings? fromJson(Object? json) => switch (json) {
    {'mode': final String mode, 'intervalSeconds': final int seconds}
        when intervals.contains(Duration(seconds: seconds)) =>
      switch (RefreshMode.values.asNameMap()[mode]) {
        final refreshMode? => RefreshSettings(
          mode: refreshMode,
          interval: Duration(seconds: seconds),
        ),
        null => null,
      },
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is RefreshSettings &&
      other.mode == mode &&
      other.interval == interval;

  @override
  int get hashCode => Object.hash(mode, interval);
}
