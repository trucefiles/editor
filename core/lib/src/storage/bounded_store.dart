import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'folders_there.dart';
import 'rel_path.dart';
import 'selection.dart';

/// [FileStore] that lets through only what the app may touch in one base
/// folder, so nothing outside is listed, read, written or deleted.
///
/// Inside [selection], three kinds of access: the files [handles] (the
/// handled file types and the app's own files, e.g. marks) are listed,
/// read and written; every other file is only read, never listed or
/// written (e.g. an image a document links). Listings walk only folders
/// inside the selection or on the way to it. Anything else fails with
/// [StoreError.outside].
///
/// Never brings back a selected subfolder that is gone: a create (of a
/// file or a folder) or move below it fails with [StoreError.notFound],
/// as for a gone root.
final class BoundedStore implements FileStore {
  const BoundedStore(this._inner, this.selection, {required this.handles});

  final FileStore _inner;
  final Selection selection;

  /// Whether a file is listed and written; asked only inside [selection].
  final bool Function(RelPath file) handles;

  /// Folders on the way to [selection] are walked but not listed.
  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) async => switch (await _inner.list(
    enterFolder: (folder) =>
        selection.reaches(folder) && (enterFolder?.call(folder) ?? true),
    includeFile: (file) =>
        _isWorkFile(file) && (includeFile?.call(file) ?? true),
  )) {
    Ok(value: final listing) => Ok(
      Listing(
        files: listing.files,
        folders: listing.folders.where(selection.covers).toList(),
        unreadable: listing.unreadable,
      ),
    ),
    Err(:final error) => Err(error),
  };

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      selection.covers(path) ? _inner.read(path) : _outside();

  @override
  Future<Result<FileEntry, StoreError>> create(
    RelPath path,
    Uint8List bytes,
  ) async {
    if (!_isWorkFile(path)) return _outside();
    return await _hasSelectedFolderOf(path)
        ? _inner.create(path, bytes)
        : const Err(StoreError.notFound);
  }

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _isWorkFile(path)
      ? _inner.replace(path, bytes, ifUnchanged: ifUnchanged)
      : _outside();

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _isWorkFile(path)
      ? _inner.delete(path, ifUnchanged: ifUnchanged)
      : _outside();

  @override
  Future<Result<void, StoreError>> createFolder(RelPath folder) async {
    if (!selection.covers(folder)) return _outside();
    return await _hasSelectedFolderOf(folder)
        ? _inner.createFolder(folder)
        : const Err(StoreError.notFound);
  }

  @override
  Future<Result<FileEntry, StoreError>> move(
    RelPath from,
    RelPath to, {
    required FileVersion ifUnchanged,
  }) async {
    if (!_isWorkFile(from) || !_isWorkFile(to)) return _outside();
    return await _hasSelectedFolderOf(to)
        ? _inner.move(from, to, ifUnchanged: ifUnchanged)
        : const Err(StoreError.notFound);
  }

  bool _isWorkFile(RelPath file) => selection.covers(file) && handles(file);

  /// Whether the selected subfolder that holds [path] is there; a whole
  /// base folder is the inner store's to check. An unreadable folder on
  /// the way can't tell, so it lets the write try.
  Future<bool> _hasSelectedFolderOf(RelPath path) async {
    final root = switch (selection) {
      WholeFolder() => null,
      final Subfolders subfolders => subfolders.rootOf(path),
    };
    if (root == null) return true;
    return switch (await _inner.foldersThere({root})) {
      Ok(value: final there) => there.contains(root),
      Err() => true,
    };
  }

  static Future<Result<T, StoreError>> _outside<T>() async =>
      const Err(StoreError.outside);
}
