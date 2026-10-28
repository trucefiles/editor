import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore store;
  late FileVersion version;

  setUp(() {
    store = MemoryFileStore();
    version = store.put('a.md', 'text').version;
  });

  test('moves the bytes and removes the original', () async {
    final moved = await moveByCopy(
      store,
      path('a.md'),
      path('sub/b.md'),
      ifUnchanged: version,
    );

    expect(moved.value.path, path('sub/b.md'));
    expect(store.textOf('sub/b.md'), 'text');
    expect(store.textOf('a.md'), isNull);
  });

  test('never overwrites a file at the target', () async {
    store.put('b.md', 'other');

    final moved = await moveByCopy(
      store,
      path('a.md'),
      path('b.md'),
      ifUnchanged: version,
    );

    expect(moved.error, StoreError.alreadyExists);
    expect(store.textOf('b.md'), 'other');
    expect(store.textOf('a.md'), 'text');
  });

  test('moves nothing if the original changed before', () async {
    store.put('a.md', 'changed');

    final moved = await moveByCopy(
      store,
      path('a.md'),
      path('b.md'),
      ifUnchanged: version,
    );

    expect(moved.error, StoreError.changedSinceRead);
    expect(store.textOf('b.md'), isNull);
  });

  test('removes the copy again if the original changed meanwhile', () async {
    final changing = _ChangesOnCreate(store, [path('a.md')]);

    final moved = await moveByCopy(
      changing,
      path('a.md'),
      path('b.md'),
      ifUnchanged: version,
    );

    expect(moved.error, StoreError.changedSinceRead);
    expect(store.textOf('a.md'), 'changed meanwhile');
    expect(store.textOf('b.md'), isNull);
  });

  test('logs a copy it could not remove again', () async {
    final changing = _ChangesOnCreate(store, [path('a.md'), path('b.md')]);
    final logged = <String>[];
    final logs = Logger.root.onRecord.listen((record) {
      logged.add(record.message);
    });
    addTearDown(logs.cancel);

    final moved = await moveByCopy(
      changing,
      path('a.md'),
      path('b.md'),
      ifUnchanged: version,
    );

    expect(moved.error, StoreError.changedSinceRead);
    expect(store.textOf('a.md'), 'changed meanwhile');
    expect(store.textOf('b.md'), 'changed meanwhile');
    expect(logged.single, contains('Kept the copy b.md of a.md'));
  });
}

/// Changes the files at [_changed] elsewhere as soon as a file is
/// created.
final class _ChangesOnCreate implements FileStore {
  _ChangesOnCreate(this._inner, this._changed);

  final MemoryFileStore _inner;
  final List<RelPath> _changed;

  @override
  Future<Result<FileEntry, StoreError>> create(
    RelPath path,
    Uint8List bytes,
  ) async {
    final created = await _inner.create(path, bytes);
    for (final changed in _changed) {
      _inner.put(changed.value, 'changed meanwhile');
    }
    return created;
  }

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _inner.read(path);

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _inner.delete(path, ifUnchanged: ifUnchanged);

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => throw UnimplementedError();

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, StoreError>> createFolder(RelPath folder) =>
      throw UnimplementedError();

  @override
  Future<Result<FileEntry, StoreError>> move(
    RelPath from,
    RelPath to, {
    required FileVersion ifUnchanged,
  }) => throw UnimplementedError();
}
