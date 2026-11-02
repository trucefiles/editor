import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_types/file_types.dart';
import '../plugins/plugins_wiring.dart';
import '../settings/device_settings_controller.dart';
import '../settings/followed_setting.dart';
import '../storage/app_storage.dart';
import 'folders_controller.dart';

final appWritesProvider = Provider<AppWrites>((ref) {
  final writes = AppWrites();
  ref.onDispose(writes.close);
  return writes;
});

/// The open folders, wired: they follow the folder list owner. Every
/// write through their services is told to [appWritesProvider]. A folder
/// that is gone is checked again at the refresh setting's interval, read
/// at each wait.
final openFoldersProvider = Provider<OpenFolders>((ref) {
  final plugins = ref.watch(folderPluginsProvider);
  final types = ref.watch(fileTypesProvider);
  final storage = ref.watch(appStorageProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final writes = ref.watch(appWritesProvider);
  final checkEvery = ref.watch(_refreshIntervalProvider);
  final open = OpenFolders(
    ref.watch(folderListOwnerProvider),
    plugins: plugins,
    build: (folder, raw, reach) => folderServices(
      raw,
      reach: reach,
      handles: types.handles,
      backupsPath: storage.backupsPath(folder.id),
      deviceId: deviceId,
      checkEvery: checkEvery,
      wrote: (paths) => writes.wrote(folder.id, paths),
    ),
  );
  ref.onDispose(() => unawaited(open.close()));
  return open;
});

/// The refresh setting's interval as it is now; read at each wait, so a
/// change never reopens the folders.
final _refreshIntervalProvider = Provider<Duration Function()>((ref) {
  final refresh = followedSetting(ref, (s) => s.refresh);
  return () => refresh().interval;
});

/// The services of the folder with this id (see [OpenFolders]): one
/// object for the folder's whole life, closed once it goes, so nothing
/// needs to hear of a close.
final folderServicesProvider = Provider.family<FolderServices, FolderId>((
  ref,
  folder,
) {
  return ref.watch(openFoldersProvider).servicesOf(folder);
});

/// How changes to the folder with this id are found, as the refresh
/// setting asks (see [folderFollowing]).
final folderFollowingProvider = Provider.family<FolderFollowing, FolderId>(
  (ref, folder) => folderFollowing(
    ref.watch(deviceSettingsProvider.select((s) => s.requireValue.refresh)),
    ref.watch(folderServicesProvider(folder)).changes,
  ),
);

/// What the user should know about the folder with this id: what its
/// plugin tells, and whether its changes are polled as they can't be
/// followed live. Checked once; invalidate to check again.
final folderNoticesProvider =
    FutureProvider.family<List<FolderNotice>, FolderId>((ref, folder) async {
      final polled = ref.watch(folderFollowingProvider(folder)).pollsInstead;
      final notices = ref.watch(folderServicesProvider(folder)).notices;
      return [
        ...await notices.check(),
        if (polled case final interval?) PolledNotice(interval),
      ];
    });
