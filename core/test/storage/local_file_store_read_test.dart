import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'local_file_store_fixture.dart';

/// Listing and reading files, and what symbolic links allow.
void main() {
  late StoreFolder fx;

  setUp(() async => fx = await StoreFolder.create());

  group('list', () {
    test('lists files recursively, hidden ones included', () async {
      await fx.write('a.md', 'a');
      await fx.write('.hidden', 'h');
      await fx.write('sub/deep/b.md', 'b');

      final result = await fx.store.list();

      final paths = result.value.files.map((e) => e.path.value).toSet();
      expect(paths, {'a.md', '.hidden', 'sub/deep/b.md'});
    });

    test('lists the folders it walked, empty ones included', () async {
      await fx.write('a/b/c/x.md', 'x');
      await fx.write('.stversions/a.md', 'old');
      Directory('${fx.root.path}/empty/deeper').createSync(recursive: true);

      final result = await fx.store.list(
        enterFolder: (folder) => folder.value != '.stversions',
      );

      expect(
        result.value.folders.map((f) => f.value),
        unorderedEquals(['a', 'a/b', 'a/b/c', 'empty', 'empty/deeper']),
      );
    });

    test('skips files that includeFile rejects', () async {
      await fx.write('a.md', 'a');
      await fx.write('sub/b.jpg', 'b');

      final result = await fx.store.list(
        includeFile: (file) => file.value.endsWith('.md'),
      );

      expect(result.value.files.map((e) => e.path.value), ['a.md']);
      expect(result.value.folders.map((f) => f.value), ['sub']);
    });

    test('skips folders that enterFolder rejects', () async {
      await fx.write('a.md', 'a');
      await fx.write('.stversions/a.md', 'old');

      final result = await fx.store.list(
        enterFolder: (folder) => folder.value != '.stversions',
      );

      final paths = result.value.files.map((e) => e.path.value);
      expect(paths, ['a.md']);
    });

    test('names files correctly if the root path ends in /', () async {
      await fx.write('abc.md', 'a');
      await fx.write('sub/def.md', 'd');
      final slashed = LocalFileStore('${fx.root.path}/', (t) => t);

      final paths = (await slashed.list()).value.files.map((e) => e.path.value);

      expect(paths.toSet(), {'abc.md', 'sub/def.md'});
    });

    test(
      'lists subfolders it cannot read as unreadable',
      () async {
        await fx.write('a.md', 'a');
        await fx.write('locked/b.md', 'b');
        await Process.run('chmod', ['000', '${fx.root.path}/locked']);
        addTearDown(
          () => Process.run('chmod', ['700', '${fx.root.path}/locked']),
        );

        final listing = (await fx.store.list()).value;

        expect(listing.files.map((e) => e.path.value), ['a.md']);
        expect(listing.folders, isEmpty);
        expect(listing.unreadable, [path('locked')]);
      },
      skip: Platform.isWindows || _isRoot()
          ? 'needs file permissions that apply'
          : false,
    );

    test('fails with notFound if the root is missing', () async {
      final missing = LocalFileStore('${fx.root.path}/missing', (t) => t);

      expect((await missing.list()).error, StoreError.notFound);
    });
  });

  group('read', () {
    test('returns bytes and a version matching the listing', () async {
      await fx.write('a.md', 'hello');

      final content = (await fx.store.read(path('a.md'))).value;
      final listed = (await fx.store.list()).value.files.single;

      expect(String.fromCharCodes(content.bytes), 'hello');
      expect(content.version, listed.version);
      expect(content.modified, listed.modified);
    });

    test('fails with notFound for a missing file', () async {
      final result = await fx.store.read(path('missing.md'));

      expect(result.error, StoreError.notFound);
    });
  });

  group('symbolic links', () {
    late Directory outside;

    setUp(() async {
      outside = await Directory.systemTemp.createTemp('truce_outside');
      await File('${outside.path}/secret.md').writeAsString('secret');
      await Link('${fx.root.path}/linked').create(outside.path);
      await Link('${fx.root.path}/note.md').create('${outside.path}/secret.md');
    });

    tearDown(() => outside.delete(recursive: true));

    test('are not listed', () async {
      expect((await fx.store.list()).value.files, isEmpty);
    });

    test('are not read, through a folder or as a file', () async {
      expect(
        (await fx.store.read(path('linked/secret.md'))).error,
        StoreError.accessDenied,
      );
      expect(
        (await fx.store.read(path('note.md'))).error,
        StoreError.accessDenied,
      );
    });

    test('are not written through', () async {
      final created = await fx.store.create(
        path('linked/new.md'),
        bytesOf('x'),
      );

      expect(created.error, StoreError.accessDenied);
      expect(File('${outside.path}/new.md').existsSync(), isFalse);
    });

    test('are not replaced or deleted, nor their targets', () async {
      final version = FileVersion((
        File('${outside.path}/secret.md').statSync().modified,
        6,
      ));

      final replaced = await fx.store.replace(
        path('note.md'),
        bytesOf('x'),
        ifUnchanged: version,
      );
      final deleted = await fx.store.delete(
        path('note.md'),
        ifUnchanged: version,
      );

      expect(replaced.error, StoreError.accessDenied);
      expect(deleted.error, StoreError.accessDenied);
      expect(Link('${fx.root.path}/note.md').existsSync(), isTrue);
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
