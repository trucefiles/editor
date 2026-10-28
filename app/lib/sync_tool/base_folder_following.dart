import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/base_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../platform/platform_facts.dart';
import '../platform/platform_wiring.dart';
import '../refresh/refresh_settings.dart';
import '../refresh/refresh_settings_controller.dart';
import 'base_folder_services.dart';

/// How a base folder's changes are found (`null`: not looked for), and how
/// often it is polled because they can't be followed live, asked at each
/// check (`null`: not polled).
typedef FolderFollowing = ({
  FolderChanges? changes,
  Duration? Function() pollInterval,
});

/// How changes to a base folder are found, as the refresh setting asks:
/// watched, one watcher per selected subfolder, and polled through its
/// services once watching fails; or only polled, at the set interval.
/// Polls tell its reach how they went, like every other access.
final folderFollowingProvider =
    FutureProvider.family<FolderFollowing, BaseFolder>((ref, base) async {
      final refresh = await ref.watch(refreshSettingsProvider.future);
      final platform = ref.watch(platformFactsProvider);
      final services = ref.watch(baseFolderServicesProvider(base));
      final selection = ref.watch(
        foldersProvider.select(
          (folders) => (folders.value ?? const []).selectionOf(base),
        ),
      );
      final polled = PolledFolderChanges(
        // A poll that works brings an unreachable folder back.
        services.store,
        interval: refresh.interval,
        followed: services.followed,
      );
      switch (_following(base.path, refresh, platform)) {
        case _Following.none:
          return (changes: null, pollInterval: () => null);
        case _Following.watched:
          final watched = FallbackFolderChanges(
            MergedFolderChanges([
              for (final root in _watchedRoots(selection))
                WatchedFolderChanges(
                  base.path,
                  followed: services.followed,
                  under: root,
                ),
            ]),
            polled,
          );
          return (
            changes: watched,
            pollInterval: () => watched.isOnFallback ? refresh.interval : null,
          );
        case _Following.polled:
          final asked = refresh.mode == RefreshMode.live;
          return (
            changes: polled,
            pollInterval: () => asked ? refresh.interval : null,
          );
      }
    });

/// The folders to watch: the base folder itself (`null`) when it is all
/// selected, else each selected subfolder.
List<RelPath?> _watchedRoots(Selection selection) => switch (selection) {
  WholeFolder() => const [null],
  Subfolders(:final roots) => [...roots],
};

/// How a base folder's changes are followed.
enum _Following { none, watched, polled }

/// The one place that decides how the base folder at [path] follows
/// changes for [refresh]: live means watched where the platform reports
/// the folder's changes, polled elsewhere.
_Following _following(
  String path,
  RefreshSettings refresh,
  PlatformFacts platform,
) => switch (refresh.mode) {
  RefreshMode.manual => _Following.none,
  RefreshMode.live when platform.reportsChangesIn(path) => _Following.watched,
  RefreshMode.live || RefreshMode.periodic => _Following.polled,
};
