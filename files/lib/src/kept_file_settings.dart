import 'package:meta/meta.dart';

import 'file_settings.dart';

/// A file's [settings] as this device keeps them, and since when its file
/// has been missing from the scans that could see it, if it is.
@immutable
final class KeptFileSettings {
  const KeptFileSettings(this.settings, {this.missingSince});

  /// How long settings outlast their missing file: a file that only looks
  /// gone for a while (a folder out of reach, a scan from before a move,
  /// a drive not mounted) gets them back.
  static const grace = Duration(days: 7);

  final FileSettings settings;

  /// `null` while the file is there, or can't be told.
  final DateTime? missingSince;

  /// These settings once a scan at [now] did not find their file: kept
  /// with the time it was first missed; `null` once [grace] is over.
  KeptFileSettings? missedAt(DateTime now) => switch (missingSince) {
    null => KeptFileSettings(settings, missingSince: now),
    final since when now.difference(since) >= grace => null,
    _ => this,
  };

  /// These settings, their file found again.
  KeptFileSettings get found => KeptFileSettings(settings);

  @override
  bool operator ==(Object other) =>
      other is KeptFileSettings &&
      other.settings == settings &&
      other.missingSince == missingSince;

  @override
  int get hashCode => Object.hash(settings, missingSince);
}
