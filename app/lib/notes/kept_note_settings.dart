import 'package:flutter/foundation.dart';

import 'note_settings.dart';

/// A note's [settings] as this device keeps them, and since when its note
/// has been missing from the scans that could see it, if it is.
@immutable
final class KeptNoteSettings {
  const KeptNoteSettings(this.settings, {this.missingSince});

  /// How long settings outlast their missing note: a note that only looks
  /// gone for a while (a folder out of reach, a scan from before a move,
  /// a drive not mounted) gets them back.
  static const grace = Duration(days: 7);

  final NoteSettings settings;

  /// `null` while the note is there, or can't be told.
  final DateTime? missingSince;

  /// These settings once a scan at [now] did not find their note: kept
  /// with the time it was first missed; `null` once [grace] is over.
  KeptNoteSettings? missedAt(DateTime now) => switch (missingSince) {
    null => KeptNoteSettings(settings, missingSince: now),
    final since when now.difference(since) >= grace => null,
    _ => this,
  };

  /// These settings, their note found again.
  KeptNoteSettings get found => KeptNoteSettings(settings);

  @override
  bool operator ==(Object other) =>
      other is KeptNoteSettings &&
      other.settings == settings &&
      other.missingSince == missingSince;

  @override
  int get hashCode => Object.hash(settings, missingSince);
}
