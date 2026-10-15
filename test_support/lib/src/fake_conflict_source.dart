import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'test_helpers.dart';

/// A made-up sync tool's conflict copies for tests of generic code. Kept
/// in memory, like a tool that records them in its own metadata instead
/// of as files next to the main file.
final class FakeConflictSource implements ConflictSource {
  /// The copies by id, oldest first.
  final Map<String, ({RelPath mainPath, FileContent content})> copies = {};

  /// When set, every operation fails with this error.
  StoreError? failWith;

  int _clock = 0;

  /// Adds a copy of [mainPath] holding [text], as the sync tool would.
  ConflictCopy put(String mainPath, String text) =>
      _put(path(mainPath), bytesOf(text));

  /// Changes [copy] to hold [text], as an edit on another device would.
  void edit(ConflictCopy copy, String text) {
    final stored = copies[copy.id]!;
    copies[copy.id] = (
      mainPath: stored.mainPath,
      content: _contentOf(bytesOf(text)),
    );
  }

  String? textOf(ConflictCopy copy) => switch (copies[copy.id]) {
    final stored? => String.fromCharCodes(stored.content.bytes),
    null => null,
  };

  /// The pending conflict of [mainPath], with [main] as scanned.
  Conflict conflictOf(String mainPath, {required FileEntry? main}) => Conflict(
    mainPath: path(mainPath),
    main: main,
    copies: [
      for (final MapEntry(:key, :value) in copies.entries)
        if (value.mainPath == path(mainPath)) _copyOf(key, value.content),
    ],
  );

  @override
  Future<Result<Uint8List, StoreError>> read(ConflictCopy copy) async {
    if (_check(copy) case final error?) return Err(error);
    return Ok(copies[copy.id]!.content.bytes);
  }

  @override
  Future<Result<void, StoreError>> discard(ConflictCopy copy) async {
    if (_check(copy) case final error?) return Err(error);
    copies.remove(copy.id);
    return const Ok(null);
  }

  @override
  Future<Result<void, StoreError>> add(
    RelPath mainPath,
    Uint8List bytes,
  ) async {
    if (failWith case final error?) return Err(error);
    _put(mainPath, bytes);
    return const Ok(null);
  }

  StoreError? _check(ConflictCopy copy) {
    if (failWith case final error?) return error;
    final stored = copies[copy.id];
    if (stored == null) return StoreError.notFound;
    return stored.content.version == copy.version
        ? null
        : StoreError.changedSinceRead;
  }

  ConflictCopy _put(RelPath mainPath, Uint8List bytes) {
    final content = _contentOf(bytes);
    final id = 'copy-$_clock';
    copies[id] = (mainPath: mainPath, content: content);
    return _copyOf(id, content);
  }

  FileContent _contentOf(Uint8List bytes) => FileContent(
    bytes,
    version: FileVersion(++_clock),
    modified: DateTime.fromMillisecondsSinceEpoch(_clock),
  );

  static ConflictCopy _copyOf(String id, FileContent content) => ConflictCopy(
    id: id,
    version: content.version,
    createdAt: content.modified,
  );
}
