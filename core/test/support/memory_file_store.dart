import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'test_helpers.dart';

/// In-memory [FileStore] for tests. Each write gets a new version and a
/// later modification time.
final class MemoryFileStore implements FileStore {
  final Map<RelPath, FileContent> files = {};

  /// When set, every operation fails with this error.
  StoreError? failWith;

  /// Folders without files; folders holding files exist implicitly.
  final Set<RelPath> emptyFolders = {};

  /// How often [list] was called.
  int listCount = 0;

  /// The files the last [list] call returned.
  List<RelPath> lastListed = const [];

  int _clock = 0;

  /// Adds or overwrites [path] without any checks.
  FileEntry put(String path, String text) =>
      _write(RelPath.parse(path)!, bytesOf(text));

  String? textOf(String path) {
    final content = files[RelPath.parse(path)!];
    return content == null ? null : String.fromCharCodes(content.bytes);
  }

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) async {
    listCount++;
    if (failWith case final error?) return Err(error);
    bool enters(RelPath folder) => enterFolder?.call(folder) ?? true;

    /// Whether [path] and every folder above it are entered.
    bool reached(RelPath? path) =>
        path == null || (enters(path) && reached(path.parent));

    final folders = {
      for (final path in [...files.keys, ...emptyFolders])
        for (var folder = path.parent; folder != null; folder = folder.parent)
          folder,
      ...emptyFolders,
    };
    final listing = Listing(
      files: [
        for (final MapEntry(key: path, value: content) in files.entries)
          if (reached(path.parent) && (includeFile?.call(path) ?? true))
            _entryOf(path, content),
      ],
      folders: [
        for (final folder in folders)
          if (reached(folder)) folder,
      ],
    );
    lastListed = [for (final entry in listing.files) entry.path];
    return Ok(listing);
  }

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) async {
    if (failWith case final error?) return Err(error);
    final content = files[path];
    return content == null ? const Err(StoreError.notFound) : Ok(content);
  }

  @override
  Future<Result<FileEntry, StoreError>> create(
    RelPath path,
    Uint8List bytes,
  ) async {
    if (failWith case final error?) return Err(error);
    if (files.containsKey(path)) return const Err(StoreError.alreadyExists);
    return Ok(_write(path, bytes));
  }

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) async {
    if (_check(path, ifUnchanged) case final error?) return Err(error);
    return Ok(_write(path, bytes));
  }

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) async {
    if (_check(path, ifUnchanged) case final error?) return Err(error);
    files.remove(path);
    return const Ok(null);
  }

  StoreError? _check(RelPath path, FileVersion expected) {
    if (failWith case final error?) return error;
    final content = files[path];
    if (content == null) return StoreError.notFound;
    return content.version == expected ? null : StoreError.changedSinceRead;
  }

  FileEntry _write(RelPath path, Uint8List bytes) {
    final content = FileContent(
      bytes,
      version: FileVersion(++_clock),
      modified: DateTime.fromMillisecondsSinceEpoch(_clock),
    );
    files[path] = content;
    return _entryOf(path, content);
  }

  static FileEntry _entryOf(RelPath path, FileContent content) =>
      FileEntry(path, version: content.version, modified: content.modified);
}
