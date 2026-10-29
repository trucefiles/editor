import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../documents/documents_wiring.dart';
import '../folders/folders_controller.dart';
import '../platform/app_activity.dart';
import '../settings/device_settings_controller.dart';
import '../sync_tool/base_folder_wiring.dart';

/// The app's folder state owner, wired: it lists the base folders the
/// stacks show, by their sync tools, the first time once the edits left by
/// the last run are in their files (so no document shows its old text
/// while its draft is pending), and again whenever what a base folder's
/// folders select changes. The app's own writes reach it as they land.
final folderStateOwnerProvider = Provider<FolderStateOwner>((ref) {
  final stacks = ref.watch(baseFolderStacksProvider);
  final owner = folderStateOwner((baseId) {
    final services = stacks.servicesOfId(baseId);
    return (scanner: services.scanner, marks: services.marks);
  });
  final writes = ref.watch(appWritesProvider).all.listen(owner.send);
  StreamSubscription<void>? bases;
  ref.onDispose(() {
    unawaited(writes.cancel());
    unawaited(bases?.cancel());
    unawaited(owner.close());
  });
  unawaited(
    ref.read(documentsProvider).draftsRecovered.then((_) {
      if (!ref.mounted) return;
      void tell() => owner.send(BasesChanged(stacks.selections));
      bases = stacks.changes.listen((_) => tell());
      tell();
    }),
  );
  return owner;
});

/// The app's following of changes, wired: what each base folder's
/// changes hint reaches the folder state owner while the app is in use,
/// as the refresh setting asks; every base folder is listed once when the
/// setting changes.
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

/// How each base folder's changes are found now, by id; none of a base
/// folder whose changes aren't looked for, and none before the folder list
/// loaded.
final _followedChangesProvider = Provider<Map<String, FolderChanges>>((ref) {
  final folders = ref.watch(foldersProvider).value ?? const [];
  return {
    for (final base in {for (final folder in folders) folder.base})
      base.id: ?ref.watch(folderFollowingProvider(base)).changes,
  };
});
