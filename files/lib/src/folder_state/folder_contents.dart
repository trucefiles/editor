import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../conflicts/folder_conflicts.dart';
import '../listed_file.dart';
import '../read_version.dart';
import '../shown_file_types.dart';

/// What the added folders hold now, as the screens show it: their
/// files (listed, never their texts), marks, subfolders, conflicts,
/// and what could not be seen. Worked out once from the folder state;
/// questions are lookups on it.
final class FolderContents {
  FolderContents(this.state, {required this.folders, required this.types});

  /// What the folders hold.
  final FolderState state;

  /// The folders the user added.
  final List<Folder> folders;

  final ShownFileTypes types;

  /// Whether every folder was listed at least once, even if that failed:
  /// until then, what shows may be missing files.
  late final bool loaded = folders.every(
    (folder) => state.folders[folder.id] is! NotListed?,
  );

  late final Map<FolderId, Folder> _byId = {
    for (final folder in folders) folder.id: folder,
  };

  /// Every file of the folders, newest first; files with the same time
  /// by folder and path, so the order never changes between listings of
  /// the same files.
  late final List<ListedFile> files = [
    for (final folder in folders)
      if (state.folders[folder.id] case Listed(:final files))
        for (final entry in files.values) ?_fileOf(folder, entry),
  ]..sort(_newestFirst);

  ListedFile? _fileOf(Folder folder, FileEntry entry) {
    final type = types.of(entry.path)?.support;
    if (type == null) return null;
    return ListedFile(
      folder: folder,
      path: entry.path,
      type: type,
      version: entry.version,
      modified: entry.modified,
    );
  }

  static int _newestFirst(ListedFile a, ListedFile b) {
    final byTime = b.modified.compareTo(a.modified);
    if (byTime != 0) return byTime;
    final byFolder = a.folder.id.compareTo(b.folder.id);
    return byFolder != 0 ? byFolder : a.path.value.compareTo(b.path.value);
  }

  late final Map<FileKey, ListedFile> _byKey = {
    for (final file in files) file.key: file,
  };

  ListedFile? findFile(FileKey key) => _byKey[key];

  /// The colors of the folders' files; unmarked ones left out.
  late final Map<FileKey, FileMark> marks = {
    for (final folder in folders)
      if (state.folders[folder.id] case Listed(:final marks))
        for (final MapEntry(key: path, value: mark) in marks.marks.entries)
          (folder: folder.id, path: path): mark,
  };

  FileMark markOf(FileKey key) => marks[key] ?? FileMark.none;

  /// The pending conflicts of the folders' files.
  late final FolderConflicts conflicts = FolderConflicts([
    for (final folder in folders)
      if (state.folders[folder.id] case Listed(:final conflicts))
        for (final conflict in conflicts.values)
          if (types.handles(conflict.mainPath))
            FolderConflict(folder, conflict),
  ]);

  /// The subfolders of [folder], empty ones too, sorted by path.
  List<RelPath> subfoldersOf(FolderId folder) => switch (_listedOf(folder)) {
    final listed? => listed.subfolders.sorted(
      (a, b) => a.value.compareTo(b.value),
    ),
    null => const [],
  };

  /// The folders that could not be listed, and why.
  late final Map<Folder, StoreError> failedFolders = {
    for (final folder in folders)
      if (state.folders[folder.id] case ListingFailed(:final error))
        folder: error,
  };

  /// Each folder's subfolders that could not be read, by folder; only
  /// folders that have some.
  late final Map<FolderId, List<RelPath>> unreadable = {
    for (final folder in folders)
      if (_listedOf(folder.id) case Listed(:final unreadable)
          when unreadable.isNotEmpty)
        folder.id: unreadable,
  };

  /// When the oldest listing behind this began: every write that ended
  /// before shows in it.
  late final Moment? listedAt = switch ([
    for (final folder in folders)
      if (state.folders[folder.id] case Listed(:final listedAt)) listedAt,
  ]) {
    [] => null,
    final all => all.reduce((oldest, at) => at.isBefore(oldest) ? at : oldest),
  };

  /// When what is known of the file at [key] was seen: writes that
  /// ended later are not in it.
  Moment? seenAt(FileKey key) => _listedOf(key.folder)?.seenAt(key.path);

  /// Whether the file at [key] is seen as it is, if it exists: its folder
  /// is one of [folders], was listed, and no subfolder above it could not
  /// be read. If not, a file missing from [files] may still exist.
  bool covers(FileKey key) => _listedOf(key.folder)?.sees(key.path) ?? false;

  /// What is known of the file at [key]: found in a version, gone, or
  /// unknown where it could not be seen (see [covers]). A file of a folder
  /// that is gone is gone.
  Observation observe(FileKey key) => switch (findFile(key)) {
    _ when !_byId.containsKey(key.folder) => const Gone(),
    _ when !covers(key) => const Unknown(),
    final found? => Found(listedVersion(found)),
    null => const Gone(),
  };

  Listed? _listedOf(FolderId folder) => switch (state.folders[folder]) {
    final Listed listed when _byId.containsKey(folder) => listed,
    _ => null,
  };
}
