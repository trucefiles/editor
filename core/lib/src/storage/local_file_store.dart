import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore] on the local file system (`dart:io`), for platforms where
/// the app can open the folder by path.
///
/// Change checks compare the [FileStamp] right before writing; a change in
/// the moment between that check and the write cannot be detected.
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
        final file = _file(path);
        // Stamp first: if the file changes while it is read, the stamp is
        // older than the bytes, so the next write fails its change check
        // instead of overwriting the change.
        final stamp = await _stamp(file);
        return FileContent(await file.readAsBytes(), stamp);
      });

  @override
  Future<Result<FileStamp, StoreError>> create(RelPath path, Uint8List bytes) =>
      _guard(() async {
        final file = _file(path);
        await file.parent.create(recursive: true);
        return _writeAtomically(
          file,
          bytes,
          isAllowed: () => _checkAbsent(file),
        );
      });

  @override
  Future<Result<FileStamp, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileStamp ifUnchanged,
  }) => _guard(() async {
    final file = _file(path);
    return _writeAtomically(
      file,
      bytes,
      isAllowed: () => _checkUnchanged(file, ifUnchanged),
    );
  });

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileStamp ifUnchanged,
  }) => _guard(() async {
    final file = _file(path);
    await _checkUnchanged(file, ifUnchanged);
    await file.delete();
  });

  File _file(RelPath path) => File('$rootPath/${path.value}');

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
          entries.add(FileEntry(path, _toStamp(stat)));
        }
      } else if (entity is Directory && (enterFolder?.call(path) ?? true)) {
        await _walk(entity, '${path.value}/', enterFolder, entries);
      }
    }
  }

  /// Writes [bytes] to a temp file next to [file], then renames it over
  /// [file]. [isAllowed] runs last before the rename and throws [_Refused]
  /// to stop it.
  Future<FileStamp> _writeAtomically(
    File file,
    Uint8List bytes, {
    required Future<void> Function() isAllowed,
  }) async {
    final temp = File('${file.parent.path}/${_tempFileName(_randomToken())}');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await isAllowed();
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    return _stamp(file);
  }

  Future<void> _checkAbsent(File file) async {
    if (await file.exists()) throw const _Refused(StoreError.alreadyExists);
  }

  Future<void> _checkUnchanged(File file, FileStamp expected) async {
    if (await _stamp(file) != expected) {
      throw const _Refused(StoreError.changedSinceRead);
    }
  }

  Future<FileStamp> _stamp(File file) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const _Refused(StoreError.notFound);
    }
    return _toStamp(stat);
  }

  static FileStamp _toStamp(FileStat stat) =>
      FileStamp(modified: stat.modified, size: stat.size);

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
