import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/base_folder.dart';
import '../refresh/refresh_settings.dart';
import '../settings/device_settings_controller.dart';
import 'base_folder_services.dart';

/// How a base folder's changes are found (`null`: not looked for), and how
/// often it is polled as live changes were asked for but can't be followed
/// there (`null`: not so).
typedef FolderFollowing = ({FolderChanges? changes, Duration? pollsInstead});

/// How changes to a base folder are found, as the refresh setting asks:
/// live, by its sync tool, where it can follow them live; else polled at
/// the set interval, the same for every sync tool. A poll asks for a
/// listing, which tells its reach how it went, like every other access.
final folderFollowingProvider =
    FutureProvider.family<FolderFollowing, BaseFolder>((ref, base) async {
      final refresh = ref.watch(
        deviceSettingsProvider.select((s) => s.requireValue.refresh),
      );
      final live = ref.watch(baseFolderServicesProvider(base)).changes;
      final polled = PolledFolderChanges(interval: refresh.interval);
      return switch (refresh.mode) {
        RefreshMode.manual => (changes: null, pollsInstead: null),
        RefreshMode.live when live != null => (
          changes: live,
          pollsInstead: null,
        ),
        RefreshMode.live => (changes: polled, pollsInstead: refresh.interval),
        RefreshMode.periodic => (changes: polled, pollsInstead: null),
      };
    });

/// What the user should know about [BaseFolder]: what its sync tool
/// tells, and whether its changes are polled as they can't be followed
/// live. Checked once; invalidate to check again.
final folderNoticesProvider =
    FutureProvider.family<List<FolderNotice>, BaseFolder>((ref, base) async {
      final following = await ref.watch(folderFollowingProvider(base).future);
      return [
        ...await ref.watch(baseFolderServicesProvider(base)).notices.check(),
        if (following.pollsInstead case final interval?) PolledNotice(interval),
      ];
    });

/// How changes to [BaseFolder] are found, as the refresh setting asks;
/// `null` if they aren't looked for (manual refresh).
final folderChangesProvider = FutureProvider.family<FolderChanges?, BaseFolder>(
  (ref, base) async =>
      (await ref.watch(folderFollowingProvider(base).future)).changes,
);
