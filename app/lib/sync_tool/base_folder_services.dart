import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:truce_core/truce_core.dart';

import '../backups/file_backups_at.dart';
import '../file_types/document_types.dart';
import '../folders/base_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../platform/platform_facts.dart';
import '../platform/platform_wiring.dart';
import '../storage/app_storage.dart';
import '../storage/device_id.dart';
import 'base_folder_following.dart';
import 'sync_tools.dart';

/// The core services for one base folder, by its sync tool, bounded to
/// what its folders show; the rest of the app sees only this.
final class BaseFolderServices {
  const BaseFolderServices({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.conflicts,
    required this.backups,
    required this.restore,
    required this.marks,
    required this.reach,
    required this.notices,
    required this.followed,
  });

  /// The base folder's files, by its sync tool; refuses anything outside
  /// what its folders show ([StoreError.outside]); tells [reach] how each
  /// access went.
  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final ConflictService conflicts;

  /// Copies of the base folder's files in app storage.
  final FileBackups backups;

  /// Puts [backups] back into the base folder.
  final BackupRestore restore;

  final DocumentMarks marks;

  /// Whether the base folder can be reached, as accesses through [store]
  /// show.
  final FolderReach reach;

  /// What the sync tool tells about the base folder.
  final FolderNotices notices;

  /// The files whose changes count: the documents, the sync tool's records
  /// of them, and the marks of all devices. Nothing else, e.g. `.git` or
  /// swap files, leads to a rescan.
  final FileFilter followed;
}

/// Builds the file layer of a base folder, for its sync tool's [rules]
/// (the temp files of atomic writes). Overridable in tests, e.g. to see
/// every path the app touches.
typedef FileLayer = FileStore Function(BaseFolder base, SyncAdapter rules);

final fileLayerProvider = Provider<FileLayer>((ref) {
  final platform = ref.watch(platformFactsProvider);
  return (base, rules) => LocalFileStore(
    base.path,
    rules.tempFileName,
    replacesInPlace: platform.replacesInPlace,
  );
});

/// One base folder's file layer and reach. They stay while what its
/// folders show changes; only the bounded services above them are built
/// again.
final _baseFolderAccessProvider =
    Provider.family<({FileStore files, FolderReach reach}), BaseFolder>((
      ref,
      base,
    ) {
      final tool = ref.watch(syncToolsProvider).of(base.toolId);
      final files = ref.watch(fileLayerProvider)(base, tool.rules);
      final reach = folderReach(files);
      ref.onDispose(() => unawaited(reach.close()));
      return (files: files, reach: reach);
    });

/// The services of a base folder, built from what its folders show now:
/// built again when that changes. Its open documents are secured before
/// (see `FolderListWork.secureOpen`); a Syncthing rewrite still pending in
/// the stack before ends there, as the user's own write.
final ProviderFamily<BaseFolderServices, BaseFolder>
baseFolderServicesProvider = Provider.family<BaseFolderServices, BaseFolder>((
  ref,
  base,
) {
  final selection = ref.watch(
    foldersProvider.select(
      (folders) => (folders.value ?? const []).selectionOf(base),
    ),
  );
  final tool = ref.watch(syncToolsProvider).of(base.toolId);
  final types = ref.watch(documentTypesProvider);
  final (:files, :reach) = ref.watch(_baseFolderAccessProvider(base));
  final bounded = BoundedStore(
    ReachReportingStore(files, reach),
    selection,
    handles: (file) =>
        types.handles(file) || DocumentMarks.files.includesFile(file),
  );
  final synced = tool.open(
    bounded,
    shown: DefaultFileFilter(tool.rules, types.detector),
    markers: baseFolderMarkers(base.path, ref.watch(platformFactsProvider)),
    // Asked at each check: watching can fall back to polling any time.
    pollInterval: () =>
        ref.read(folderFollowingProvider(base)).value?.pollInterval(),
  );
  final backups = fileBackupsAt(
    ref.watch(appStorageProvider).backupsPath(base.id),
  );
  return BaseFolderServices(
    store: synced.store,
    scanner: synced.scanner,
    syncToolName: tool.rules.name,
    conflicts: DefaultConflictService(
      folder: synced.store,
      source: synced.conflicts,
      backups: backups,
    ),
    backups: backups,
    restore: BackupRestore(folder: synced.store, backups: backups),
    marks: DocumentMarks(synced.store, deviceId: ref.watch(deviceIdProvider)),
    reach: reach,
    notices: synced.notices,
    followed: AnyFileFilter([synced.followed, DocumentMarks.files]),
  );
});

/// A sync tool's look at the base folder at [basePath] and above, for its
/// own markers only.
FolderMarkers baseFolderMarkers(String basePath, PlatformFacts platform) =>
    LocalFolderMarkers(
      basePath,
      seesParents: platform.canReadParentsOf(basePath),
    );

/// The folder names of the base folder at a path, for the user to pick
/// subfolders. Overridable in tests.
final subfolderNamesProvider = Provider<SubfolderNames Function(String)>(
  (_) => LocalSubfolderNames.new,
);

/// What the user should know about [BaseFolder]. Checked once; invalidate
/// to check again.
final folderNoticesProvider =
    FutureProvider.family<List<FolderNotice>, BaseFolder>((ref, base) async {
      // How changes are followed shows in the notices.
      await ref.watch(folderFollowingProvider(base).future);
      return ref.watch(baseFolderServicesProvider(base)).notices.check();
    });

/// How changes to [BaseFolder] are found, as the refresh setting asks;
/// `null` if they aren't looked for (manual refresh).
final folderChangesProvider = FutureProvider.family<FolderChanges?, BaseFolder>(
  (ref, base) async =>
      (await ref.watch(folderFollowingProvider(base).future)).changes,
);
