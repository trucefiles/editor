import 'package:truce_core/truce_core.dart';

import 'fake_copy_names.dart';
import 'fake_live_changes.dart';
import 'fake_sync_rules.dart';
import 'memory_file_store.dart';

/// A made-up plugin with no files on disk, for tests of generic code: each
/// folder is a place of its own in memory ([FakeFolder]), kept as long as
/// the plugin, also once forgotten. A folder's id is the name its
/// [candidate] was made for, so tests know it ([folderId]).
final class FakePlugin implements FolderPlugin {
  FakePlugin([this.id = 'fake']);

  @override
  final String id;

  final _set = <String>[];
  final _made = <String, FakeFolder>{};

  /// A candidate for the folder [name], as an add page returns it.
  static PluginFolderCandidate candidate(String name) => PluginFolderCandidate(
    defaultName: name,
    location: 'fake:$name',
    detail: name,
  );

  @override
  String get name => 'Fake $id';

  @override
  String get helpLine => 'Folders in memory';

  @override
  bool load(Object? blob) {
    _set.clear();
    switch (blob) {
      case null:
        return true;
      case final List<Object?> ids when ids.every((id) => id is String):
        _set.addAll(ids.cast());
        return true;
      default:
        return false;
    }
  }

  @override
  Object? get blob => [..._set];

  @override
  List<PluginFolder> get folders => [for (final id in _set) _folderOf(id)];

  @override
  Result<List<PluginFolder>, AddRefused> add(
    List<PluginFolderCandidate> candidates,
  ) {
    final ids = [for (final candidate in candidates) candidate.detail as String];
    if (ids.any(_set.contains) || ids.toSet().length < ids.length) {
      return const Err(AddRefused.overlaps);
    }
    _set.addAll(ids);
    return Ok([for (final id in ids) _folderOf(id)]);
  }

  @override
  void forget(String id) => _set.remove(id);

  @override
  FakeFolder open(String id) => folder(id);

  /// The folder [id] in memory, also one not set up (yet or any more).
  FakeFolder folder(String id) => _made[id] ??= FakeFolder();

  static PluginFolder _folderOf(String id) =>
      PluginFolder(id: id, location: 'fake:$id');
}

/// One folder of a [FakePlugin]: files in memory, changes the test gives.
final class FakeFolder implements RawFolder {
  @override
  final MemoryFileStore files = MemoryFileStore();

  @override
  final FakeLiveChanges changes = FakeLiveChanges();

  /// What the fake plugin shows: no hidden files, none of its own.
  static final _shown = VisibleFileFilter(const FakeSyncRules().isInternal);

  @override
  OpenFolder open(BoundedPlace bounded) {
    final store = bounded.files;
    return OpenFolder(
      bounded,
      store: store,
      scanner: NamedCopiesScanner(store, _shown, const FakeCopyNames()),
      showsFolder: _shown.includesFolderPath,
      conflicts: NamedConflictSource(store, const FakeCopyNames()),
      notices: const _NoNotices(),
      changes: bounded.changes,
    );
  }
}

final class _NoNotices implements FolderNotices {
  const _NoNotices();

  @override
  Future<List<FolderNotice>> check() async => const [];
}
