import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/test_helpers.dart';

void main() {
  late Directory root;
  late LocalFileStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('truce_store_test');
    store = LocalFileStore(root.path, (token) => '.tmp-$token');
  });

  tearDown(() async {
    // Some tests remove the root.
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> write(String relPath, String text) async {
    final file = File('${root.path}/$relPath');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  String? textAt(String relPath) {
    final file = File('${root.path}/$relPath');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  Future<FileVersion> versionOf(String relPath) async =>
      (await store.read(path(relPath))).value.version;

  group('list', () {
    test('lists files recursively, hidden ones included', () async {
      await write('a.md', 'a');
      await write('.hidden', 'h');
      await write('sub/deep/b.md', 'b');

      final result = await store.list();

      final paths = result.value.map((e) => e.path.value).toSet();
      expect(paths, {'a.md', '.hidden', 'sub/deep/b.md'});
    });

    test('skips folders that enterFolder rejects', () async {
      await write('a.md', 'a');
      await write('.stversions/a.md', 'old');

      final result = await store.list(
        enterFolder: (folder) => folder.value != '.stversions',
      );

      final paths = result.value.map((e) => e.path.value);
      expect(paths, ['a.md']);
    });

    test('names files correctly if the root path ends in /', () async {
      await write('abc.md', 'a');
      await write('sub/def.md', 'd');
      final slashed = LocalFileStore('${root.path}/', (t) => t);

      final paths = (await slashed.list()).value.map((e) => e.path.value);

      expect(paths.toSet(), {'abc.md', 'sub/def.md'});
    });

    test(
      'skips subfolders it cannot read',
      () async {
        await write('a.md', 'a');
        await write('locked/b.md', 'b');
        await Process.run('chmod', ['000', '${root.path}/locked']);
        addTearDown(() => Process.run('chmod', ['700', '${root.path}/locked']));

        final paths = (await store.list()).value.map((e) => e.path.value);

        expect(paths, ['a.md']);
      },
      skip: Platform.isWindows || _isRoot()
          ? 'needs file permissions that apply'
          : false,
    );

    test('fails with notFound if the root is missing', () async {
      final missing = LocalFileStore('${root.path}/missing', (t) => t);

      expect((await missing.list()).error, StoreError.notFound);
    });
  });

  group('read', () {
    test('returns bytes and a version matching the listing', () async {
      await write('a.md', 'hello');

      final content = (await store.read(path('a.md'))).value;
      final listed = (await store.list()).value.single;

      expect(String.fromCharCodes(content.bytes), 'hello');
      expect(content.version, listed.version);
      expect(content.modified, listed.modified);
    });

    test('fails with notFound for a missing file', () async {
      final result = await store.read(path('missing.md'));

      expect(result.error, StoreError.notFound);
    });
  });

  group('create', () {
    test('writes a new file and its parent folders', () async {
      final result = await store.create(path('sub/new.md'), bytesOf('new'));

      expect(result.value.path, path('sub/new.md'));
      expect(result.value.version, await versionOf('sub/new.md'));
      expect(textAt('sub/new.md'), 'new');
    });

    test('fails with alreadyExists and keeps the file', () async {
      await write('a.md', 'old');

      final result = await store.create(path('a.md'), bytesOf('new'));

      expect(result.error, StoreError.alreadyExists);
      expect(textAt('a.md'), 'old');
      expect(root.listSync(), hasLength(1));
    });

    test('never recreates a missing root folder', () async {
      // E.g. the folder was moved or deleted, or its drive is not mounted.
      await root.delete();

      final result = await store.create(path('sub/new.md'), bytesOf('new'));

      expect(result.error, StoreError.notFound);
      expect(root.existsSync(), isFalse);
    });

    test('creates a missing root folder if told to', () async {
      await root.delete();
      final appStore = LocalFileStore(
        '${root.path}/backups',
        (token) => '.tmp-$token',
        createsRoot: true,
      );

      final result = await appStore.create(path('a.md'), bytesOf('a'));

      expect(result, isA<Ok<FileEntry, StoreError>>());
      expect(textAt('backups/a.md'), 'a');
    });
  });

  group('replace', () {
    test('replaces an unchanged file and leaves no temp file', () async {
      await write('a.md', 'old');
      final version = await versionOf('a.md');

      final result = await store.replace(
        path('a.md'),
        bytesOf('new text'),
        ifUnchanged: version,
      );

      expect(textAt('a.md'), 'new text');
      expect(result.value.version, await versionOf('a.md'));
      expect(root.listSync().map((e) => e.uri.pathSegments.last), ['a.md']);
    });

    test('keeps the file\'s permissions', () async {
      await write('a.md', 'old');
      await Process.run('chmod', ['600', '${root.path}/a.md']);
      final version = await versionOf('a.md');

      await store.replace(path('a.md'), bytesOf('new'), ifUnchanged: version);

      final mode = File('${root.path}/a.md').statSync().modeString();
      expect(mode, 'rw-------');
    }, skip: Platform.isWindows ? 'no Unix permissions' : false);

    test('fails with changedSinceRead and writes nothing', () async {
      await write('a.md', 'old');
      final version = await versionOf('a.md');
      await write('a.md', 'changed elsewhere');

      final result = await store.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      expect(result.error, StoreError.changedSinceRead);
      expect(textAt('a.md'), 'changed elsewhere');
      expect(root.listSync(), hasLength(1));
    });

    test('fails with notFound for a missing file', () async {
      await write('a.md', 'old');
      final version = await versionOf('a.md');
      await File('${root.path}/a.md').delete();

      final result = await store.replace(
        path('a.md'),
        bytesOf('new'),
        ifUnchanged: version,
      );

      expect(result.error, StoreError.notFound);
      expect(root.listSync(), isEmpty);
    });
  });

  group('delete', () {
    test('deletes an unchanged file', () async {
      await write('a.md', 'old');

      final result = await store.delete(
        path('a.md'),
        ifUnchanged: await versionOf('a.md'),
      );

      expect(result, isA<Ok<void, StoreError>>());
      expect(textAt('a.md'), isNull);
    });

    test('keeps a changed file', () async {
      await write('a.md', 'old');
      final version = await versionOf('a.md');
      await write('a.md', 'changed elsewhere');

      final result = await store.delete(path('a.md'), ifUnchanged: version);

      expect(result.error, StoreError.changedSinceRead);
      expect(textAt('a.md'), 'changed elsewhere');
    });

    test('never deletes a folder', () async {
      await write('sub/a.md', 'a');
      final version = (await store.list()).value.single.version;

      final result = await store.delete(path('sub'), ifUnchanged: version);

      expect(result.error, StoreError.notFound);
      expect(textAt('sub/a.md'), 'a');
    });
  });

  test('replace never writes over a folder', () async {
    await write('sub/a.md', 'a');
    final version = (await store.list()).value.single.version;

    final result = await store.replace(
      path('sub'),
      bytesOf('new'),
      ifUnchanged: version,
    );

    expect(result, isA<Err<FileEntry, StoreError>>());
    expect(textAt('sub/a.md'), 'a');
  });

  group('symbolic links', () {
    late Directory outside;

    setUp(() async {
      outside = await Directory.systemTemp.createTemp('truce_outside');
      await File('${outside.path}/secret.md').writeAsString('secret');
      await Link('${root.path}/linked').create(outside.path);
      await Link('${root.path}/note.md').create('${outside.path}/secret.md');
    });

    tearDown(() => outside.delete(recursive: true));

    test('are not listed', () async {
      expect((await store.list()).value, isEmpty);
    });

    test('are not read, through a folder or as a file', () async {
      expect(
        (await store.read(path('linked/secret.md'))).error,
        StoreError.accessDenied,
      );
      expect(
        (await store.read(path('note.md'))).error,
        StoreError.accessDenied,
      );
    });

    test('are not written through', () async {
      final created = await store.create(path('linked/new.md'), bytesOf('x'));

      expect(created.error, StoreError.accessDenied);
      expect(File('${outside.path}/new.md').existsSync(), isFalse);
    });

    test('are not replaced or deleted, nor their targets', () async {
      final version = FileVersion((
        File('${outside.path}/secret.md').statSync().modified,
        6,
      ));

      final replaced = await store.replace(
        path('note.md'),
        bytesOf('x'),
        ifUnchanged: version,
      );
      final deleted = await store.delete(path('note.md'), ifUnchanged: version);

      expect(replaced.error, StoreError.accessDenied);
      expect(deleted.error, StoreError.accessDenied);
      expect(Link('${root.path}/note.md').existsSync(), isTrue);
      expect(File('${outside.path}/secret.md').readAsStringSync(), 'secret');
    });
  });
}

/// Root reads any folder, whatever its permissions.
bool _isRoot() =>
    Platform.isLinux &&
    File('/proc/self/status')
        .readAsLinesSync()
        .any((line) => RegExp(r'^Uid:\s+0\s').hasMatch(line));
