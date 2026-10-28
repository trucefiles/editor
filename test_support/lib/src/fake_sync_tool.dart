import 'package:truce_core/truce_core.dart';

import 'fake_copy_names.dart';
import 'fake_live_changes.dart';
import 'fake_sync_adapter.dart';
import 'memory_file_store.dart';

/// A made-up sync tool with no files on disk, for tests of generic code:
/// each address is a place of its own in memory ([FakePlace]), kept as
/// long as the tool. Syncs the addresses in [recognizes].
final class FakeSyncTool implements SyncTool {
  FakeSyncTool(this.id, {this.recognizes = const {}});

  @override
  final String id;

  final Set<Uri> recognizes;

  final _places = <Uri, FakePlace>{};

  @override
  String get name => 'Fake $id';

  @override
  bool isToolFolder(List<String> names) =>
      const FakeSyncAdapter().isInternalFolder(names);

  @override
  Future<SyncStatus> recognize(Uri address) async =>
      recognizes.contains(address) ? SyncStatus.synced : SyncStatus.unknown;

  @override
  Future<bool> missesOldVersions(Uri address) async => false;

  @override
  FakePlace place(Uri address) => _places[address] ??= FakePlace();
}

/// One place of a [FakeSyncTool]: files in memory, changes the test gives.
final class FakePlace implements ToolPlace {
  @override
  final MemoryFileStore files = MemoryFileStore();

  @override
  final FakeLiveChanges changes = FakeLiveChanges();

  @override
  SubfolderNames get subfolders => _ListedNames(files);

  @override
  SyncedFolder open(FileStore store, {required FolderChanges? changes}) {
    final shown = VisibleFileFilter(const FakeSyncAdapter().isInternal);
    return SyncedFolder(
      store: store,
      scanner: NamedCopiesScanner(store, shown, const FakeCopyNames()),
      conflicts: NamedConflictSource(store, const FakeCopyNames()),
      notices: const _NoNotices(),
      changes: changes,
      shown: shown,
    );
  }
}

/// The folder names in a store, from a listing that walks only the folder
/// asked about and the way to it.
final class _ListedNames implements SubfolderNames {
  const _ListedNames(this._files);

  final FileStore _files;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async {
    final listed = await _files.list(
      enterFolder: (inner) =>
          folder != null && folder.isAtOrInside(inner) ||
          inner.parent == folder,
      includeFile: (_) => false,
    );
    return switch (listed) {
      Ok(value: final listing) => Ok(
        [
          for (final inner in listing.folders)
            if (inner.parent == folder) inner.name,
        ]..sort(),
      ),
      Err(:final error) => Err(error),
    };
  }
}

final class _NoNotices implements FolderNotices {
  const _NoNotices();

  @override
  Future<List<FolderNotice>> check() async => const [];
}
