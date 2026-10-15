import 'package:truce_core/truce_core.dart';

import '../../refresh/ui/interval_text.dart';

/// The words for a [FolderNotice] of a folder synced by [tool].
extension FolderNoticeText on FolderNotice {
  /// The full text, for the folders screen.
  String text(String tool) => switch (this) {
    NotSyncedNotice() =>
      'Not inside a $tool folder. Changes may not reach your other devices.',
    SyncUnknownNotice() =>
      "Can't check whether $tool syncs this folder. Add the $tool folder "
          'itself to confirm.',
    PolledNotice(:final interval) =>
      "Live updates aren't possible for this folder. It's checked for "
          'changes every ${intervalText(interval)}.',
  };

  /// A few words, e.g. for a tooltip.
  String shortText(String tool) => switch (this) {
    NotSyncedNotice() => 'Not inside a $tool folder',
    SyncUnknownNotice() => "Can't check whether $tool syncs this folder",
    PolledNotice(:final interval) => 'Checked every ${intervalText(interval)}',
  };
}
