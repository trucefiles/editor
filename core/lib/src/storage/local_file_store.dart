import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
final class LocalFileStore implements FileStore {
  LocalFileStore(this.rootPath, this._tempFileName);

  /// Absolute path of the root folder.
  final String rootPath;

  final TempFileNamer _tempFileName;
  final Random _random = Random.secure();

  @override
  Future<Result<List<FileEntry>, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
  }) => _guard(() async {
    final entries = <FileEntry>[];
    await _walk(Directory(rootPath), '', enterFolder, entries);
    return entries;
  });

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _guard(() async {
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
  }) => _guard(() async {
    final file = await _file(path);
    return _writeAtomically(
      path,
      file,
      bytes,
      isAllowed: () => _checkUnchanged(file, ifUnchanged),
    );
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
    bool Function(RelPath folder)? enterFolder,
    List<FileEntry> entries,
  ) async {
    await for (final entity in folder.list(followLinks: false)) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final path = RelPath.parse('$prefix$name');
      if (path == null) continue;
      if (entity is File) {
        // Files come and go while walking (e.g. the sync tool's temp
        // files); one that is gone by now is skipped.
        final stat = await entity.stat();
        if (stat.type == FileSystemEntityType.file) {
          entries.add(_entry(path, stat));
        }
      } else if (entity is Directory && (enterFolder?.call(path) ?? true)) {
        // A subfolder that can't be read (e.g. `lost+found`) or is gone by
        // now is skipped, so it doesn't hide the rest of the folder.
        try {
          await _walk(entity, '${path.value}/', enterFolder, entries);
        } on PathAccessException {
          continue;
        } on PathNotFoundException {
          continue;
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

  /// Creates [temp] with [file]'s permissions, if [file] exists, so the
  /// rename keeps them (e.g. a private note stays private). A copy is the
  /// only way `dart:io` creates a file with a given mode; the process's
  /// umask still applies, so permissions can only get stricter.
  Future<void> _copyModeOf(File file, File temp) async {
    try {
      await file.copy(temp.path);
    } on PathNotFoundException {
      // A new file: it gets the default permissions.
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
