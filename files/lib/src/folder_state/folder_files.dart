import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../conflicts/folder_conflicts.dart';
import '../listed_file.dart';
import '../read_version.dart';
import '../shown_file_types.dart';

/// What the added folders hold now, as the screens show it: their
/// files (listed, never their texts), marks, subfolders, conflicts,
/// and what could not be seen. Worked out once from what the folder
/// state found, never from when; questions are lookups on it.
final class FolderFiles {
  FolderFiles(FolderState state, {required this.folders, required this.types})
    : _listings = {
        for (final folder in folders)
          folder.id: state.folders[folder.id] ?? const NotListed(),
      };

  /// How far each folder is known; of a listed one, only what was found
  /// counts here.
  final Map<FolderId, ListingState> _listings;

  /// The folders the user added.
  final List<Folder> folders;

  final ShownFileTypes types;

  /// Whether [state] holds what these were made of, for the same
  /// [folders] and [types]: what each folder found is the same object, or
  /// it is unknown for the same reason.
  bool madeOf(
    FolderState state, {
    required List<Folder> folders,
    required ShownFileTypes types,
  }) =>
      identical(folders, this.folders) &&
      identical(types, this.types) &&
      folders.every(
        (folder) => switch ((_listings[folder.id], state.folders[folder.id])) {
          (Listed(found: final before), Listed(:final found)) => identical(
            before,
            found,
          ),
          (ListingFailed(error: final before), ListingFailed(:final error)) =>
            before == error,
          (NotListed(), NotListed() || null) => true,
          _ => false,
        },
      );

  /// Whether every folder was listed at least once, even if that failed:
  /// until then, what shows may be missing files.
  late final bool loaded = _listings.values.every(
    (listing) => listing is! NotListed,
  );

  late final Map<FolderId, Folder> _byId = {
    for (final folder in folders) folder.id: folder,
  };

  /// Every file of the folders, newest first; files with the same time
  /// by folder and path, so the order never changes between listings of
  /// the same files.
  late final List<ListedFile> files = [
    for (final folder in folders)
      if (_found(folder.id) case FolderFound(:final files))
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
      if (_found(folder.id) case FolderFound(:final marks))
        for (final MapEntry(key: path, value: mark) in marks.marks.entries)
          (folder: folder.id, path: path): mark,
  };

  FileMark markOf(FileKey key) => marks[key] ?? FileMark.none;

  /// The pending conflicts of the folders' files.
  late final FolderConflicts conflicts = FolderConflicts([
    for (final folder in folders)
      if (_found(folder.id) case FolderFound(:final conflicts))
        for (final conflict in conflicts.values)
          if (types.handles(conflict.mainPath))
            FolderConflict(folder, conflict),
  ]);

  /// The subfolders of [folder], empty ones too, sorted by path.
  List<RelPath> subfoldersOf(FolderId folder) => switch (_found(folder)) {
    FolderFound(:final subfolders) => subfolders.sorted(
      (a, b) => a.value.compareTo(b.value),
    ),
    _ => const [],
  };

  /// The folders that could not be listed, and why.
  late final Map<Folder, StoreError> failedFolders = {
    for (final folder in folders)
      if (_listings[folder.id] case ListingFailed(:final error)) folder: error,
  };

  /// Each folder's subfolders that could not be read, by folder; only
  /// folders that have some.
  late final Map<FolderId, List<RelPath>> unreadable = {
    for (final folder in folders)
      if (_found(folder.id) case FolderFound(:final unreadable)
          when unreadable.isNotEmpty)
        folder.id: unreadable,
  };

  /// Whether the file at [key] is seen as it is, if it exists: its folder
  /// is one of [folders], was listed, and no subfolder above it could not
  /// be read. If not, a file missing from [files] may still exist.
  bool covers(FileKey key) => _found(key.folder)?.sees(key.path) ?? false;

  /// What is known of the file at [key]: found in a version, gone, or
  /// unknown where it could not be seen (see [covers]). A file of a folder
  /// that is gone is gone.
  Observation observe(FileKey key) => switch (findFile(key)) {
    _ when !_byId.containsKey(key.folder) => const Gone(),
    _ when !covers(key) => const Unknown(),
    final found? => Found(listedVersion(found)),
    null => const Gone(),
  };

  /// What [folder] was found to hold; `null` if not known.
  FolderFound? _found(FolderId folder) => switch (_listings[folder]) {
    Listed(:final found) => found,
    _ => null,
  };
}
