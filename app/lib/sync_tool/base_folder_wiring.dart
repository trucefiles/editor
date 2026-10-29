import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_types/document_types.dart';
import '../folders/folders_controller.dart';
import '../settings/device_settings_controller.dart';
import '../storage/app_storage.dart';
import 'sync_tools_wiring.dart';

final appWritesProvider = Provider<AppWrites>((ref) {
  final writes = AppWrites();
  ref.onDispose(writes.close);
  return writes;
});

/// The stacks of the base folders, wired: they follow the folder list
/// owner. Every write through their services is told to
/// [appWritesProvider]. A followed subfolder that is gone is checked again
/// at the refresh setting's interval, read at each wait.
final baseFolderStacksProvider = Provider<BaseFolderStacks>((ref) {
  final tools = ref.watch(syncToolsProvider);
  final types = ref.watch(documentTypesProvider);
  final storage = ref.watch(appStorageProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final writes = ref.watch(appWritesProvider);
  final stacks = BaseFolderStacks(
    ref.watch(folderListOwnerProvider),
    tools: tools,
    build: (base, place, reach, selection) => baseFolderServices(
      place,
      syncToolName: tools.of(base.toolId).name,
      reach: reach,
      selection: selection,
      handles: types.handles,
      backupsPath: storage.backupsPath(base.id),
      deviceId: deviceId,
      checkEvery: () =>
          (ref.mounted
                  ? ref.read(deviceSettingsProvider).requireValue.refresh
                  : RefreshSettings.standard)
              .interval,
      wrote: (paths) => writes.wrote(base.id, paths),
    ),
  );
  ref.onDispose(() => unawaited(stacks.close()));
  return stacks;
});

/// Counts the times the stacks built or retired services, so whatever
/// watches a base folder's services gets the new ones. Counted a
/// microtask later: the stacks may hear of a change while a provider
/// builds, and a provider may not change another one then.
final _stacksBuiltProvider = NotifierProvider<_StacksBuilt, int>(
  _StacksBuilt.new,
);

class _StacksBuilt extends Notifier<int> {
  @override
  int build() {
    final built = ref
        .watch(baseFolderStacksProvider)
        .changes
        .listen(
          (_) => scheduleMicrotask(() {
            if (ref.mounted) state++;
          }),
        );
    ref.onDispose(() => unawaited(built.cancel()));
    return 0;
  }
}

/// The services of a base folder, as its folders show it now (see
/// [BaseFolderStacks]).
final baseFolderServicesProvider =
    Provider.family<BaseFolderServices, BaseFolder>((ref, base) {
      ref.watch(_stacksBuiltProvider);
      return ref.watch(baseFolderStacksProvider).servicesOf(base);
    });

/// The folder names of [BaseFolder], for the user to pick subfolders.
final subfolderNamesProvider = Provider.family<SubfolderNames, BaseFolder>(
  (ref, base) => ref.watch(baseFolderStacksProvider).placeOf(base).subfolders,
);

/// Whether the sync tool of [BaseFolder] shows a folder, and each folder on
/// the way to it (see [ToolPlace.showsFolder]).
final showsFolderProvider =
    Provider.family<bool Function(RelPath folder), BaseFolder>(
      (ref, base) =>
          ref.watch(baseFolderStacksProvider).placeOf(base).showsFolder,
    );

/// How changes to [BaseFolder] are found, as the refresh setting asks (see
/// [folderFollowing]).
final folderFollowingProvider = Provider.family<FolderFollowing, BaseFolder>(
  (ref, base) => folderFollowing(
    ref.watch(deviceSettingsProvider.select((s) => s.requireValue.refresh)),
    ref.watch(baseFolderServicesProvider(base)).changes,
  ),
);

/// What the user should know about [BaseFolder]: what its sync tool
/// tells, and whether its changes are polled as they can't be followed
/// live. Checked once; invalidate to check again.
final folderNoticesProvider =
    FutureProvider.family<List<FolderNotice>, BaseFolder>((ref, base) async {
      final polled = ref.watch(folderFollowingProvider(base)).pollsInstead;
      final notices = ref.watch(baseFolderServicesProvider(base)).notices;
      return [
        ...await notices.check(),
        if (polled case final interval?) PolledNotice(interval),
      ];
    });
