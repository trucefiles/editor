import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

/// Proves that every write the app makes to a synced folder touches only the
/// files the user acted on: never Syncthing's own files, other files, other
/// folders or anything outside the folder.
void main() {
  late Directory base;
  late Directory notes;
  late Directory backups;
  late FolderServices services;
  late NoteFiles files;

  setUp(() {
    base = tempFolder();
    notes = Directory('${base.path}/Notes')..createSync();
    backups = Directory('${base.path}/app/backups/f1');
    _populate(base);
    final folder = folderAt(notes);
    services = FolderServices.syncthing(
      notes.path,
      backupsPath: backups.path,
      deviceId: '0123456789abcdef',
    );
    files = NoteFiles(folder, services);
  });

  /// Every entry below [base], with what a write would change.
  Map<String, String> snapshot() => _snapshot(base);

  /// The note at [name], as the app reads it.
  Future<Note> noteAt(String name) async {
    final scan = (await services.scanner.scan()).value;
    final entry = scan.files.firstWhere((file) => file.path.value == name);
    final placeholder = Note(
      folder: folderAt(notes),
      path: entry.path,
      file: TextFile.empty(),
      version: entry.version,
      modified: entry.modified,
    );
    return (await files.reload(placeholder)).value;
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
    });
    expect(changed(before, snapshot()), isEmpty);
  });

  test('creating a note adds only that note', () async {
    final before = snapshot();

    await files.create('New');

    expect(changed(before, snapshot()), {'Notes/New.md'});
  });

  test('saving a note changes only that note', () async {
    final note = await noteAt('sub/b.md');
    final before = snapshot();

    await files.save(note, 'edited');

    expect(changed(before, snapshot()), {'Notes/sub/b.md'});
  });

  test('deleting a note and undoing it touch only that note', () async {
    final note = await noteAt('sub/b.md');
    final before = snapshot();

    await files.delete(note);
    expect(changed(before, snapshot()), {'Notes/sub/b.md'});
    expect(Directory('${notes.path}/sub').existsSync(), isTrue);

    await files.restore(note, note.file.text);
    final restored = File('${notes.path}/sub/b.md').readAsStringSync();
    expect(restored, note.file.text);
  });

  test('pinning a note adds only this device\'s marks file', () async {
    final before = snapshot();

    await services.marks.set(path('a.md'), const NoteMark(pinned: true));

    expect(changed(before, snapshot()), {
      'Notes/.truce',
      'Notes/.truce/marks',
      'Notes/.truce/marks/0123456789abcdef.json',
    });
  });

  test('keeping edits as a conflict copy adds only the copy', () async {
    final note = await noteAt('sub/b.md');
    final before = snapshot();

    await files.saveAsConflict(note, 'mine');

    final added = changed(before, snapshot());
    expect(added, hasLength(1));
    expect(added.single, startsWith('Notes/sub/b.sync-conflict-'));
  });

  for (final resolution in [const KeepCurrent(), const KeepOther()]) {
    test('resolving a conflict with ${resolution.runtimeType} touches only '
        'the note and its copy', () async {
      File('${notes.path}/sub/b.sync-conflict-20261003-134809-ABCDEFG.md')
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
        if (resolution is KeepOther) 'Notes/sub/b.md',
        'Notes/sub/b.sync-conflict-20261003-134809-ABCDEFG.md',
      });
    });
  }

  group('once the folder is gone', () {
    // E.g. moved, deleted, or on a drive that is not mounted.
    late Note note;
    late Map<String, String> before;

    setUp(() async {
      note = await noteAt('sub/b.md');
      notes.renameSync('${base.path}/Moved');
      before = snapshot();
    });

    test('creating a note does not bring it back', () async {
      expect((await files.create('New')).error, StoreError.notFound);
      expect(changed(before, snapshot()), isEmpty);
    });

    test('pinning a note does not bring it back', () async {
      final pinned = await services.marks.set(
        path('a.md'),
        const NoteMark(pinned: true),
      );

      expect(pinned.error, StoreError.notFound);
      expect(changed(before, snapshot()), isEmpty);
    });

    test('keeping edits as a conflict copy does not bring it back', () async {
      expect(
        (await files.saveAsConflict(note, 'mine')).error,
        StoreError.notFound,
      );
      expect(changed(before, snapshot()), isEmpty);
    });

    test('saving, restoring and deleting do not bring it back', () async {
      expect((await files.save(note, 'mine')).error, StoreError.notFound);
      expect((await files.restore(note, 'mine')).error, StoreError.notFound);
      expect((await files.delete(note)).error, StoreError.notFound);
      expect(changed(before, snapshot()), isEmpty);
    });
  });
}

/// A Syncthing folder `Notes` with the tool's own files, files and folders
/// the app does not show, a link to a folder outside, and files next to it.
void _populate(Directory base) {
  void write(String path, String text) => (File(
    '${base.path}/$path',
  )..createSync(recursive: true)).writeAsStringSync(text);

  Directory('${base.path}/Notes/.stfolder').createSync();
  write('Notes/.stignore', '// ignore nothing\n');
  write('Notes/.stversions/a~20261001-120000.md', 'old a');
  write('Notes/.stversions/sub/b~20261001-120000.md', 'old b');
  write('Notes/a.md', '# A\n');
  write('Notes/sub/b.md', '# B\n- [ ] item\n');
  write('Notes/sub/deeper/c.md', '# C\n');
  write('Notes/sub/picture.png', 'not text');
  write('Notes/readme.txt', 'plain text');
  write('Notes/.hidden/h.md', '# Hidden\n');
  write('Notes/.syncthing.a.md.tmp', 'Syncthing at work');
  write('outside/secret.md', '# Secret\n');
  write('sibling.md', '# Sibling\n');
  Link('${base.path}/Notes/linked').createSync('${base.path}/outside');
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
