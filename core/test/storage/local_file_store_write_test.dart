import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'local_file_store_fixture.dart';

/// Creating, replacing and deleting files.
void main() {
  late StoreFolder fx;

  setUp(() async => fx = await StoreFolder.create());

  group('create', () {
    test('writes a new file and its parent folders', () async {
      final result = await fx.store.create(path('sub/new.md'), bytesOf('new'));

      expect(result.value.path, path('sub/new.md'));
      expect(result.value.version, await fx.versionOf('sub/new.md'));
      expect(fx.textAt('sub/new.md'), 'new');
    });

    test('fails with alreadyExists and keeps the file', () async {
      await fx.write('a.md', 'old');

      final result = await fx.store.create(path('a.md'), bytesOf('new'));

      expect(result.error, StoreError.alreadyExists);
      expect(fx.textAt('a.md'), 'old');
      expect(fx.root.listSync(), hasLength(1));
    });

    test('never recreates a missing root folder', () async {
      // E.g. the folder was moved or deleted, or its drive is not mounted.
      await fx.root.delete();

      final result = await fx.store.create(path('sub/new.md'), bytesOf('new'));

      expect(result.error, StoreError.notFound);
      expect(fx.root.existsSync(), isFalse);
    });

    test('creates a missing root folder if told to', () async {
      await fx.root.delete();
      final appStore = LocalFileStore(
        '${fx.root.path}/backups',
        (token) => '.tmp-$token',
        createsRoot: true,
      );

      final result = await appStore.create(path('a.md'), bytesOf('a'));

      expect(result, isA<Ok<FileEntry, StoreError>>());
      expect(fx.textAt('backups/a.md'), 'a');
    });
  });

  group('replace', () {
    test('replaces an unchanged file and leaves no temp file', () async {
      await fx.write('a.md', 'old');
      final version = await fx.versionOf('a.md');

      final result = await fx.store.replace(
        path('a.md'),
        bytesOf('new text'),
        ifUnchanged: version,
      );

      expect(fx.textAt('a.md'), 'new text');
      expect(result.value.version, await fx.versionOf('a.md'));
      expect(fx.names(), ['a.md']);
    });

    test('keeps the file\'s permissions', () async {
      await fx.write('a.md', 'old');
      await Process.run('chmod', ['600', '${fx.root.path}/a.md']);
      final version = await fx.versionOf('a.md');

      await fx.store.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      final mode = File('${fx.root.path}/a.md').statSync().modeString();
      expect(mode, 'rw-------');
    }, skip: Platform.isWindows ? 'no Unix permissions' : false);

    test('fails with changedSinceRead and writes nothing', () async {
      final version = await fx.changedSinceRead('a.md');

      final result = await fx.store.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      expect(result.error, StoreError.changedSinceRead);
      expect(fx.textAt('a.md'), 'changed elsewhere');
      expect(fx.root.listSync(), hasLength(1));
    });

    test('fails with notFound for a missing file', () async {
      final version = await fx.deletedSinceRead('a.md');

      final result = await fx.store.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      expect(result.error, StoreError.notFound);
      expect(fx.root.listSync(), isEmpty);
    });
  });

  group('replace in place', () {
    late LocalFileStore inPlace;

    setUp(() {
      inPlace = LocalFileStore(
        fx.root.path,
        (token) => '.tmp-$token',
        replacesInPlace: true,
      );
    });

    Future<Result<FileEntry, StoreError>> replace(String text) async =>
        inPlace.replace(
          path('a.md'),
          bytesOf(text),
          ifUnchanged: await fx.versionOf('a.md'),
        );

    test('a read during a write sees the old or the new file', () async {
      const size = 32 << 20;
      await fx.write('a.md', 'a' * size);

      final version = await fx.versionOf('a.md');
      final writing = inPlace.replace(
        path('a.md'),
        bytesOf('b' * size),
        ifUnchanged: version,
      );
      var written = false;
      unawaited(writing.then((_) => written = true));
      final reads = <Result<FileContent, StoreError>>[];
      while (!written) {
        reads.add(await inPlace.read(path('a.md')));
      }

      for (final read in reads) {
        final text = String.fromCharCodes(read.value.bytes);
        expect(text.length, size);
        expect({text[0], text[size - 1]}, hasLength(1));
      }
    });

    test('replaces the text and leaves no temp file', () async {
      await fx.write('a.md', 'old');

      final result = await replace('new text');

      expect(fx.textAt('a.md'), 'new text');
      expect(result.value.version, await fx.versionOf('a.md'));
      expect(fx.names(), ['a.md']);
    });

    test('writes into the existing file', () async {
      await fx.write('a.md', 'old');
      // A hard link shares the file: it sees the new text only if the
      // store wrote into the file instead of renaming a new one over it.
      await Process.run('ln', ['${fx.root.path}/a.md', '${fx.root.path}/link']);

      await replace('new');

      expect(fx.textAt('link'), 'new');
    }, skip: Platform.isWindows ? 'no ln' : false);

    test('fails with changedSinceRead and writes nothing', () async {
      final version = await fx.changedSinceRead('a.md');

      final result = await inPlace.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      expect(result.error, StoreError.changedSinceRead);
      expect(fx.textAt('a.md'), 'changed elsewhere');
      expect(fx.root.listSync(), hasLength(1));
    });

    test('never recreates a deleted file', () async {
      final version = await fx.deletedSinceRead('a.md');

      final result = await inPlace.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      expect(result.error, StoreError.notFound);
      expect(fx.root.listSync(), isEmpty);
    });
  });

  group('delete', () {
    test('deletes an unchanged file', () async {
      await fx.write('a.md', 'old');

      final result = await fx.store.delete(
        path('a.md'),
        ifUnchanged: await fx.versionOf('a.md'),
      );

      expect(result, isA<Ok<void, StoreError>>());
      expect(fx.textAt('a.md'), isNull);
    });

    test('keeps a changed file', () async {
      final version = await fx.changedSinceRead('a.md');

      final result = await fx.store.delete(path('a.md'), ifUnchanged: version);

      expect(result.error, StoreError.changedSinceRead);
      expect(fx.textAt('a.md'), 'changed elsewhere');
    });

    test('never deletes a folder', () async {
      await fx.write('sub/a.md', 'a');
      final version = (await fx.store.list()).value.files.single.version;

      final result = await fx.store.delete(path('sub'), ifUnchanged: version);

      expect(result.error, StoreError.notFound);
      expect(fx.textAt('sub/a.md'), 'a');
    });
  });

  group('move', () {
    test('moves an unchanged file, never over another one', () async {
      await fx.write('a.md', 'a');
      await fx.write('taken.md', 'other');
      final version = await fx.versionOf('a.md');

      final taken = await fx.store.move(
        path('a.md'),
        path('taken.md'),
        ifUnchanged: version,
      );
      final moved = await fx.store.move(
        path('a.md'),
        path('sub/b.md'),
        ifUnchanged: version,
      );

      expect(taken.error, StoreError.alreadyExists);
      expect(fx.textAt('taken.md'), 'other');
      expect(moved.value.path, path('sub/b.md'));
      expect(fx.textAt('sub/b.md'), 'a');
      expect(fx.textAt('a.md'), isNull);
    });

    test('keeps a changed file where it is', () async {
      final version = await fx.changedSinceRead('a.md');

      final moved = await fx.store.move(
        path('a.md'),
        path('b.md'),
        ifUnchanged: version,
      );

      expect(moved.error, StoreError.changedSinceRead);
      expect(fx.textAt('a.md'), 'changed elsewhere');
      expect(fx.textAt('b.md'), isNull);
    });
  });

  test('replace never writes over a folder', () async {
    await fx.write('sub/a.md', 'a');
    final version = (await fx.store.list()).value.files.single.version;

    final result = await fx.store.replace(
      path('sub'),
      bytesOf('new'),
      ifUnchanged: version,
    );

    expect(result, isA<Err<FileEntry, StoreError>>());
    expect(fx.textAt('sub/a.md'), 'a');
  });
}
