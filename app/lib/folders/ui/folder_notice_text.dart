import 'package:truce_core/truce_core.dart';

import '../../common/interval_text.dart';

/// The words for a [FolderNotice] of a folder synced by [tool], the
/// plugin's name.
extension FolderNoticeText on FolderNotice {
  /// The full text, for the folders screen.
  String text(String tool) => switch (this) {
    NotSyncedNotice() =>
      "$tool doesn't sync this folder, so changes may not reach other "
          'devices.',
    SyncUnknownNotice() =>
      "Can't check whether $tool syncs this folder. Adding the folder "
          '$tool shares itself, not one inside it, lets the app check.',
    PolledNotice(:final interval) =>
      "Live updates aren't possible here; checked for changes every "
          '${intervalText(interval)}.',
  };

  /// A few words, e.g. for a tooltip.
  String shortText(String tool) => switch (this) {
    NotSyncedNotice() => 'Not synced by $tool',
    SyncUnknownNotice() => "Can't check whether $tool syncs this folder",
    PolledNotice(:final interval) => 'Checked every ${intervalText(interval)}',
  };
}
