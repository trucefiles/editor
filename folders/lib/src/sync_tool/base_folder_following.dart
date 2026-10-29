import 'package:truce_core/truce_core.dart';

import '../refresh/refresh_settings.dart';

/// How a base folder's changes are found (`null`: not looked for), and how
/// often it is polled as live changes were asked for but can't be followed
/// there (`null`: not so).
typedef FolderFollowing = ({FolderChanges? changes, Duration? pollsInstead});

/// How changes to a base folder are found, as [refresh] asks: live, by its
/// sync tool ([live]; `null` where it can't follow them live); else polled
/// at the set interval, the same for every sync tool. A poll asks for a
/// listing, which tells its reach how it went, like every other access.
FolderFollowing folderFollowing(RefreshSettings refresh, FolderChanges? live) {
  final polled = PolledFolderChanges(interval: refresh.interval);
  return switch (refresh.mode) {
    RefreshMode.manual => (changes: null, pollsInstead: null),
    RefreshMode.live when live != null => (changes: live, pollsInstead: null),
    RefreshMode.live => (changes: polled, pollsInstead: refresh.interval),
    RefreshMode.periodic => (changes: polled, pollsInstead: null),
  };
}
