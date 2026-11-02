import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../files/files_wiring.dart';
import '../folders/folders_controller.dart';
import '../folders/open_folders_wiring.dart';
import '../platform/app_activity.dart';
import '../settings/device_settings_controller.dart';

/// The app's folder state owner, wired: it lists the open folders, once
/// [folderListingProvider] tells it which. The app's own writes reach it
/// as they land.
final folderStateOwnerProvider = Provider<FolderStateOwner>((ref) {
  final open = ref.watch(openFoldersProvider);
  final owner = folderStateOwner((folder) {
    final services = open.servicesOf(folder);
    return (scanner: services.scanner, marks: services.marks);
  });
  final writes = ref.watch(appWritesProvider).all.listen(owner.send);
  ref.onDispose(() {
    unawaited(writes.cancel());
    unawaited(owner.close());
  });
  return owner;
});

/// The listing of the folders, wired: the first once the edits left by
/// the last run are in their files (so no file shows its old text while
/// its draft is pending), and again whenever the folder list changes.
/// Apart from the owner, as the file steps ask the owner's state and this
/// waits for the files.
final folderListingProvider = Provider<void>((ref) {
  final owner = ref.watch(folderStateOwnerProvider);
  final folderList = ref.watch(folderListOwnerProvider);
  StreamSubscription<void>? lists;
  ref.onDispose(() => unawaited(lists?.cancel()));
  unawaited(
    ref.read(filesProvider).draftsRecovered.then((_) {
      if (!ref.mounted) return;
      void tell(FolderListState list) => owner.send(
        FoldersChanged({
          if (list case FoldersLoaded(:final folders))
            for (final folder in folders) folder.id,
        }),
      );
      lists = folderList.changes.listen(tell);
      tell(folderList.state);
    }),
  );
});

/// The app's following of changes, wired: what each folder's changes
/// hint reaches the folder state owner while the app is in use, as the
/// refresh setting asks; every folder is listed once when the setting
/// changes.
final followingChangesProvider = Provider<FollowingChanges>((ref) {
  final following = FollowingChanges(ref.watch(folderStateOwnerProvider));
  ref.onDispose(following.close);
  void follow() => following.follow(
    active: ref.read(appActiveProvider),
    changes: ref.read(_followedChangesProvider),
  );
  ref
    ..listen(appActiveProvider, (_, _) => follow())
    ..listen(_followedChangesProvider, (_, _) => follow())
    ..listen(
      deviceSettingsProvider.select((s) => s.requireValue.refresh),
      (_, _) => following.listAgain(),
    );
  follow();
  return following;
});

/// How each folder's changes are found now, by id; none of a folder
/// whose changes aren't looked for, and none before the folder list
/// loaded.
final _followedChangesProvider = Provider<Map<FolderId, FolderChanges>>((ref) {
  final folders = ref.watch(foldersProvider).value ?? const [];
  return {
    for (final folder in folders)
      folder.id: ?ref.watch(folderFollowingProvider(folder.id)).changes,
  };
});
