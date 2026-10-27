import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../common/keyed_task_queue.dart';
import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore] on the local file system (`dart:io`), for platforms where
/// the app can open the folder by path.
///
/// Change checks compare the [FileVersion] right before writing; a change in
/// the moment between that check and the write cannot be detected.
///
/// Never follows symbolic links below the root, so it cannot reach files
/// outside the root folder: [list] skips them, and every other operation
/// fails with [StoreError.accessDenied] if its path goes through one.
///
/// Never creates the root folder unless [createsRoot]: a missing root means
/// the folder was moved, deleted or is on a drive that is not mounted, so
/// [create] fails with [StoreError.notFound] instead of bringing it back.
final class LocalFileStore implements FileStore {
  LocalFileStore(
    this.rootPath,
    this._tempFileName, {
    this.createsRoot = false,
    this.replacesInPlace = false,
  });

  /// Absolute path of the root folder.
  final String rootPath;

  /// Whether [create] may create a missing root folder, e.g. for the app's
  /// own storage, which exists only once something is saved there.
  final bool createsRoot;

  /// Whether [replace] writes into the existing file instead of renaming
  /// a new file over it. For file systems where a renamed-over file shows
  /// other apps the old file's modification time a moment later (Android
  /// shared storage), so a sync tool would miss the change.
  ///
  /// Not atomic: if the app is killed mid-write, the file is cut short.
  /// Reads and writes of one file then run one at a time, so a read never
  /// sees a write half done.
  final bool replacesInPlace;

  final TempFileNamer _tempFileName;
  final Random _random = Random.secure();

  /// Reads and in-place writes per file, while [replacesInPlace].
  final _turns = KeyedTaskQueue<RelPath>();

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _guard(() async {
    final listing = Listing(files: [], folders: [], unreadable: []);
    await _walk(Directory(rootPath), '', (
      enterFolder: enterFolder ?? _all,
      includeFile: includeFile ?? _all,
    ), listing);
    return listing;
  });

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _inTurn(path, () async {
        final file = await _file(path);
        // Version first: if the file changes while it is read, the version
        // is older than the bytes, so the next write fails its change check
        // instead of overwriting the change.
        final stat = await _stat(file);
        return FileContent(
          await file.readAsBytes(),
          version: _version(stat),
          modified: stat.modified,
        );
      });

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      _guard(() async {
        final file = await _file(path);
        if (!createsRoot) await _checkRootExists();
        await file.parent.create(recursive: true);
        return _writeAtomically(
          path,
          file,
          bytes,
          isAllowed: () => _checkAbsent(file),
        );
      });

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _inTurn(path, () async {
    final file = await _file(path);
    Future<void> isAllowed() => _checkUnchanged(file, ifUnchanged);
    return replacesInPlace
        ? _writeInPlace(path, file, bytes, isAllowed: isAllowed)
        : _writeAtomically(path, file, bytes, isAllowed: isAllowed);
  });

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _guard(() async {
    final file = await _file(path);
    await _checkUnchanged(file, ifUnchanged);
    await file.delete();
  });

  /// Runs [action] guarded; while [replacesInPlace], after every earlier
  /// read or write of [path] that runs in turn.
  Future<Result<T, StoreError>> _inTurn<T>(
    RelPath path,
    Future<T> Function() action,
  ) =>
      replacesInPlace ? _turns.run(path, () => _guard(action)) : _guard(action);

  /// The file at [path]; refused if any part of the path below the root
  /// is a symbolic link.
  Future<File> _file(RelPath path) async {
    var prefix = rootPath;
    for (final segment in path.value.split('/')) {
      prefix = '$prefix/$segment';
      final type = await FileSystemEntity.type(prefix, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const _Refused(StoreError.accessDenied);
      }
      if (type == FileSystemEntityType.notFound) break;
    }
    return File('$rootPath/${path.value}');
  }

  Future<void> _walk(
    Directory folder,
    String prefix,
    _Filters filters,
    Listing listing,
  ) async {
    await for (final entity in folder.list(followLinks: false)) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final path = RelPath.parse('$prefix$name');
      if (path == null) continue;
      if (entity is File && filters.includeFile(path)) {
        // Files come and go while walking (e.g. the sync tool's temp
        // files); one that is gone by now is skipped.
        final stat = await entity.stat();
        if (stat.type == FileSystemEntityType.file) {
          listing.files.add(_entry(path, stat));
        }
      } else if (entity is Directory && filters.enterFolder(path)) {
        // A subfolder that is gone by now is skipped; one that can't be read
        // (e.g. `lost+found`) is reported, so it doesn't hide the rest of
        // the folder and what is below it doesn't look deleted.
        try {
          await _walk(entity, '${path.value}/', filters, listing);
          listing.folders.add(path);
        } on PathNotFoundException {
          continue;
        } on FileSystemException {
          listing.unreadable.add(path);
        }
      }
    }
  }

  /// Writes [bytes] to a temp file next to [file], then renames it over
  /// [file]. [isAllowed] runs last before the rename and throws [_Refused]
  /// to stop it.
  ///
  /// The returned entry is the temp file's: a rename keeps the file's
  /// times and size. Reading [file] again after the rename could return a
  /// change made in that moment, which the next write would then overwrite.
  Future<FileEntry> _writeAtomically(
    RelPath path,
    File file,
    Uint8List bytes, {
    required Future<void> Function() isAllowed,
  }) async {
    final temp = File('${file.parent.path}/${_tempFileName(_randomToken())}');
    try {
      await _copyModeOf(file, temp);
      await temp.writeAsBytes(bytes, flush: true);
      final written = await _stat(temp);
      await isAllowed();
      await temp.rename(file.path);
      return _entry(path, written);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  /// Writes [bytes] into the existing [file]. [isAllowed] runs last before
  /// the write and throws [_Refused] to stop it.
  ///
  /// The bytes go to a temp file first, so a full disk fails before [file]
  /// is touched.
  Future<FileEntry> _writeInPlace(
    RelPath path,
    File file,
    Uint8List bytes, {
    required Future<void> Function() isAllowed,
  }) async {
    final temp = File('${file.parent.path}/${_tempFileName(_randomToken())}');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await isAllowed();
      await file.writeAsBytes(bytes, flush: true);
      return _entry(path, await _stat(file));
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  /// Creates [temp] with [file]'s permissions, if [file] exists, so the
  /// rename keeps them (e.g. a private document stays private). A copy is the
  /// only way `dart:io` creates a file with a given mode; the process's
  /// umask still applies, so permissions can only get stricter.
  Future<void> _copyModeOf(File file, File temp) async {
    try {
      await file.copy(temp.path);
    } on PathNotFoundException {
      // A new file: it gets the default permissions.
    }
  }

  Future<void> _checkRootExists() async {
    if (!await FileSystemEntity.isDirectory(rootPath)) {
      throw const _Refused(StoreError.notFound);
    }
  }

  Future<void> _checkAbsent(File file) async {
    if (await file.exists()) throw const _Refused(StoreError.alreadyExists);
  }

  Future<void> _checkUnchanged(File file, FileVersion expected) async {
    if (_version(await _stat(file)) != expected) {
      throw const _Refused(StoreError.changedSinceRead);
    }
  }

  /// The stat of [file]; refused if it is not a file.
  Future<FileStat> _stat(File file) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const _Refused(StoreError.notFound);
    }
    return stat;
  }

  static FileEntry _entry(RelPath path, FileStat stat) =>
      FileEntry(path, version: _version(stat), modified: stat.modified);

  /// A file's modification time and size: a new version of a file changes
  /// at least one of them.
  static FileVersion _version(FileStat stat) =>
      FileVersion((stat.modified, stat.size));

  String _randomToken() =>
      List.generate(8, (_) => _random.nextInt(16).toRadixString(16)).join();
}

bool _all(RelPath _) => true;

/// The filters of one [LocalFileStore.list] call.
typedef _Filters = ({
  bool Function(RelPath folder) enterFolder,
  bool Function(RelPath file) includeFile,
});

/// Turns expected file-system failures into [Err] values.
Future<Result<T, StoreError>> _guard<T>(Future<T> Function() action) async {
  try {
    return Ok(await action());
  } on _Refused catch (refused) {
    return Err(refused.error);
  } on PathNotFoundException {
    return const Err(StoreError.notFound);
  } on PathExistsException {
    return const Err(StoreError.alreadyExists);
  } on PathAccessException {
    return const Err(StoreError.accessDenied);
  } on FileSystemException {
    return const Err(StoreError.ioFailure);
  }
}

/// A check failed; carried to [_guard] as an exception to keep the
/// operations linear.
final class _Refused implements Exception {
  const _Refused(this.error);

  final StoreError error;
}
