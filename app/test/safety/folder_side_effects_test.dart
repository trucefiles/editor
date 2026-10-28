import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_files.dart';
import 'package:truce_editor/documents/document_text.dart';
import 'package:truce_editor/sync_tool/base_folder_services.dart';

import '../support.dart';

/// Proves that every write the app makes to a synced folder touches only the
/// files the user acted on: never Syncthing's own files, other files, other
/// folders or anything outside the folder.
void main() {
  late Directory base;
  late Directory documents;
  late Directory backups;
  late BaseFolderServices services;
  late DocumentFiles files;

  setUp(() {
    base = tempFolder();
    documents = Directory('${base.path}/Documents')..createSync();
    backups = Directory('${base.path}/app/backups/f1');
    _populate(base);
    final folder = folderAt(documents);
    services = servicesFor(folder, backupsPath: backups.path);
    files = DocumentFiles(folder, services, appDocumentTypes());
  });

  /// Every entry below [base], with what a write would change.
  Map<String, String> snapshot() => _snapshot(base);

  /// The document at [name], as the app reads it.
  Future<DocumentText> documentAt(String name) async {
    final scan = (await services.scanner.scan()).value;
    final entry = scan.files.firstWhere((file) => file.path.value == name);
    final listed = Document(
      folder: folderAt(documents),
      path: entry.path,
      type: appDocumentTypes().of(entry.path)!.support,
      version: entry.version,
      modified: entry.modified,
    );
    return (await files.reload(listed)).value;
  }

  /// Entries that differ between [before] and [after], by path.
  Set<String> changed(Map<String, String> before, Map<String, String> after) =>
      {
        for (final key in {...before.keys, ...after.keys})
          if (before[key] != after[key]) key,
      };

  test('scanning and reading change nothing', () async {
    final before = snapshot();

    final scan = (await services.scanner.scan()).value;
    for (final entry in scan.files) {
      await services.store.read(entry.path);
    }
    await services.marks.load();

    expect(scan.files.map((file) => file.path.value).toSet(), {
      'a.md',
      'sub/b.md',
      'sub/deeper/c.md',
      'readme.txt',
    });
    expect(changed(before, snapshot()), isEmpty);
  });

  test('creating a document adds only that document', () async {
    final before = snapshot();

    await files.create('New', type: appDocumentTypes().forNew);

    expect(changed(before, snapshot()), {'Documents/New.md'});
  });

  test('saving a document changes only that document', () async {
    final document = await documentAt('sub/b.md');
    final before = snapshot();

    await files.save(document, 'edited');

    expect(changed(before, snapshot()), {'Documents/sub/b.md'});
  });

  test('deleting a document and undoing it touch only that document', () async {
    final document = await documentAt('sub/b.md');
    final before = snapshot();

    await files.delete(document.document);
    expect(changed(before, snapshot()), {'Documents/sub/b.md'});
    expect(Directory('${documents.path}/sub').existsSync(), isTrue);

    await files.restore(document, document.text);
    final restored = File('${documents.path}/sub/b.md').readAsStringSync();
    expect(restored, document.text);
  });

  test('coloring a document adds only this device\'s marks file', () async {
    final before = snapshot();

    await services.marks.set(path('a.md'), const DocumentMark(color: 'teal'));

    expect(changed(before, snapshot()), {
      'Documents/.truce',
      'Documents/.truce/marks',
      'Documents/.truce/marks/0123456789abcdef.json',
    });
  });

  test('keeping edits as a conflict copy adds only the copy', () async {
    final document = await documentAt('sub/b.md');
    final before = snapshot();

    await files.saveAsConflict(document, 'mine');

    final added = changed(before, snapshot());
    expect(added, hasLength(1));
    expect(added.single, startsWith('Documents/sub/b.sync-conflict-'));
  });

  for (final resolution in [const KeepCurrent(), const KeepOther()]) {
    test('resolving a conflict with ${resolution.runtimeType} touches only '
        'the document and its copy', () async {
      File('${documents.path}/sub/b.sync-conflict-20261003-134809-ABCDEFG.md')
          .writeAsStringSync('theirs');
      final scan = (await services.scanner.scan()).value;
      final conflict = scan.conflicts.single;
      final before = snapshot();

      final resolved = await services.conflicts.resolve(
        conflict,
        conflict.copies.single,
        resolution,
      );

      expect(resolved, isA<Ok<void, ResolveError>>());
      // Backups go to app storage, outside the folder.
      final inFolder = {
        for (final path in changed(before, snapshot()))
          if (path != 'app' && !path.startsWith('app/')) path,
      };
      expect(inFolder, {
        if (resolution is KeepOther) 'Documents/sub/b.md',
        'Documents/sub/b.sync-conflict-20261003-134809-ABCDEFG.md',
      });
    });
  }

  group('once the folder is gone', () {
    // E.g. moved, deleted, or on a drive that is not mounted.
    late DocumentText document;
    late Map<String, String> before;

    setUp(() async {
      document = await documentAt('sub/b.md');
      documents.renameSync('${base.path}/Moved');
      before = snapshot();
    });

    test('creating a document does not bring it back', () async {
      expect(
        (await files.create('New', type: appDocumentTypes().forNew)).error,
        StoreError.notFound,
      );
      expect(changed(before, snapshot()), isEmpty);
    });

    test('coloring a document does not bring it back', () async {
      final colored = await services.marks.set(
        path('a.md'),
        const DocumentMark(color: 'teal'),
      );

      expect(colored.error, StoreError.notFound);
      expect(changed(before, snapshot()), isEmpty);
    });

    test('keeping edits as a conflict copy does not bring it back', () async {
      expect(
        (await files.saveAsConflict(document, 'mine')).error,
        StoreError.notFound,
      );
      expect(changed(before, snapshot()), isEmpty);
    });

    test('saving, restoring and deleting do not bring it back', () async {
      expect((await files.save(document, 'mine')).error, StoreError.notFound);
      expect(
        (await files.restore(document, 'mine')).error,
        StoreError.notFound,
      );
      expect(
        (await files.delete(document.document)).error,
        StoreError.notFound,
      );
      expect(changed(before, snapshot()), isEmpty);
    });
  });
}

/// A Syncthing folder `Documents` with the tool's own files, files and folders
/// the app does not show, a link to a folder outside, and files next to it.
void _populate(Directory base) {
  void write(String path, String text) =>
      File('${base.path}/$path').writeCreatingFolders(text);

  Directory('${base.path}/Documents/.stfolder').createSync();
  write('Documents/.stignore', '// ignore nothing\n');
  write('Documents/.stversions/a~20261001-120000.md', 'old a');
  write('Documents/.stversions/sub/b~20261001-120000.md', 'old b');
  write('Documents/a.md', '# A\n');
  write('Documents/sub/b.md', '# B\n- [ ] item\n');
  write('Documents/sub/deeper/c.md', '# C\n');
  write('Documents/sub/picture.png', 'not text');
  write('Documents/readme.txt', 'plain text');
  write('Documents/.hidden/h.md', '# Hidden\n');
  write('Documents/.syncthing.a.md.tmp', 'Syncthing at work');
  write('outside/secret.md', '# Secret\n');
  write('sibling.md', '# Sibling\n');
  Link('${base.path}/Documents/linked').createSync('${base.path}/outside');
}

/// Each entry below [root] by relative path: a file's bytes, time and mode,
/// a link's target, or that a folder exists.
Map<String, String> _snapshot(Directory root) => {
  for (final entity in root.listSync(recursive: true, followLinks: false))
    entity.path.substring(root.path.length + 1): switch (entity) {
      File() =>
        'file ${entity.readAsBytesSync()} '
            '${entity.statSync().modified} ${entity.statSync().mode}',
      Link() => 'link ${entity.targetSync()}',
      _ => 'folder',
    },
};
