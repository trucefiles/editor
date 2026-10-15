import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteFiles files;
  late Note note;
  late NoteEditSession session;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() async {
    dir = tempFolder();
    final folder = folderAt(dir);
    files = NoteFiles(folder, servicesFor(folder));
    note = (await files.create('a')).value;
    session = NoteEditSession(
      note,
      files,
      tempDrafts(),
      saveDelay: Duration.zero,
    );
    addTearDown(session.dispose);
  });

  File file() => File('${dir.path}/a.md');

  String onDisk() => file().readAsStringSync();

  /// Simulates an edit from another device and returns the new version.
  Future<Note> editElsewhere(String text) async {
    file().writeAsStringSync(text);
    return (await files.reload(note)).value;
  }

  test('saves edits', () async {
    session.edit('# a\nmine');
    await session.flush();

    expect(onDisk(), '# a\nmine');
    expect(session.state, EditState.saved);
  });

  test('takes changes from elsewhere while nothing is unsaved', () async {
    final theirs = await editElsewhere('# a\ntheirs');

    final replaced = session.onRescan(theirs, scannedAt: later);

    expect(replaced, isTrue);
    expect(session.text, '# a\ntheirs');
  });

  test('ignores scans that started before its last write', () async {
    session.edit('# a\nmine');
    await session.flush();

    final replaced = session.onRescan(note, scannedAt: DateTime(2000));

    expect(replaced, isFalse);
    expect(session.text, '# a\nmine');
  });

  test('ignores scans that started during its last write', () async {
    session.edit('# a\nmine');
    final saving = session.flush();
    // Lets the save start its write, which then waits for the disk.
    await Future<void>.delayed(Duration.zero);
    final scannedAt = DateTime.now();
    await saving;

    final replaced = session.onRescan(note, scannedAt: scannedAt);

    expect(replaced, isFalse);
    expect(session.text, '# a\nmine');
  });

  /// Simulates a file system reporting a new version for unchanged content.
  Future<Note> restamp() async {
    file().setLastModifiedSync(DateTime(2001));
    return (await files.reload(note)).value;
  }

  test('a new version with the same text is not a change', () async {
    session.edit('# a\nmine');
    await session.flush();
    final restamped = await restamp();

    session.edit('# a\nmine, more');
    session.onRescan(restamped, scannedAt: later);
    await session.flush();

    expect(session.state, EditState.saved);
    expect(onDisk(), '# a\nmine, more');
  });

  test('saves over a file that was only restamped', () async {
    session.edit('# a\nmine');
    await session.flush();
    await restamp();

    session.edit('# a\nmine, more');
    await session.flush();

    expect(session.state, EditState.saved);
    expect(onDisk(), '# a\nmine, more');
  });

  test('asks before overwriting a change from elsewhere', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();

    expect(session.state, EditState.changedElsewhere);
    expect(onDisk(), '# a\ntheirs, longer');
  });

  test('a change elsewhere to the same text is not a conflict', () async {
    await editElsewhere('# a\nsame');
    session.edit('# a\nsame');
    await session.flush();

    expect(session.state, EditState.saved);
  });

  test('a rescan finding the same text is not a conflict', () async {
    final waiting = NoteEditSession(
      note,
      files,
      tempDrafts(),
      saveDelay: const Duration(hours: 1),
    );
    addTearDown(waiting.dispose);
    waiting.edit('# a\nsame');
    final theirs = await editElsewhere('# a\nsame');

    waiting.onRescan(theirs, scannedAt: later);

    expect(waiting.state, EditState.saved);
    expect(waiting.note.version, theirs.version);
  });

  test('keep mine overwrites the change from elsewhere', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();

    await session.keepMine();

    expect(onDisk(), '# a\nmine');
    expect(session.state, EditState.saved);
  });

  test('keep mine asks again if the file changed once more', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();
    await editElsewhere('# a\ntheirs, even longer');

    await session.keepMine();
    expect(session.state, EditState.changedElsewhere);
    expect(onDisk(), '# a\ntheirs, even longer');

    await session.keepMine();
    expect(onDisk(), '# a\nmine');
  });

  test('load theirs drops the edits', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();

    session.loadTheirs();

    expect(session.text, '# a\ntheirs, longer');
    expect(session.state, EditState.saved);
  });

  test('stops saving a note deleted elsewhere', () async {
    file().deleteSync();
    session.edit('# a\nkept');
    await session.flush();

    expect(session.state, EditState.deletedElsewhere);

    session.edit('# a\nkept, more');
    await session.flush();

    expect(file().existsSync(), isFalse);
    expect(session.text, '# a\nkept, more');
  });

  test('a rescan reports a note deleted elsewhere', () {
    session.onRescan(null, scannedAt: later);

    expect(session.state, EditState.deletedElsewhere);
  });

  test('saves again once a note that looked deleted is back', () async {
    session.onRescan(null, scannedAt: later);
    session.edit('# a\nmine');

    session.onRescan(note, scannedAt: later);
    await session.flush();

    expect(session.state, EditState.saved);
    expect(onDisk(), '# a\nmine');
  });

  test('shows a note back with other text if there were no edits', () async {
    session.onRescan(null, scannedAt: later);
    final theirs = await editElsewhere('# a\ntheirs');

    session.onRescan(theirs, scannedAt: later);

    expect(session.state, EditState.saved);
    expect(session.text, '# a\ntheirs');
  });

  test('a note back with other text is a change from elsewhere', () async {
    session.onRescan(null, scannedAt: later);
    session.edit('# a\nmine');
    final theirs = await editElsewhere('# a\ntheirs');

    session.onRescan(theirs, scannedAt: later);

    expect(session.state, EditState.changedElsewhere);
  });

  test('restore mine writes the text again', () async {
    file().deleteSync();
    session.edit('# a\nkept');
    await session.flush();

    await session.restoreMine();

    expect(onDisk(), '# a\nkept');
    expect(session.state, EditState.saved);
  });

  group('secure', () {
    List<String> conflictCopies() => [
      for (final f in dir.listSync())
        if (f.path.contains('.sync-conflict-')) File(f.path).readAsStringSync(),
    ];

    test('saves pending edits as usual', () async {
      session.edit('# a\nmine');

      expect(await session.secure(), isTrue);
      expect(onDisk(), '# a\nmine');
      expect(conflictCopies(), isEmpty);
    });

    test(
      'keeps edits as a conflict copy if the note changed elsewhere',
      () async {
        await editElsewhere('# a\ntheirs, longer');
        session.edit('# a\nmine');

        expect(await session.secure(), isTrue);
        expect(session.state, EditState.keptAsConflict);
        expect(onDisk(), '# a\ntheirs, longer');
        expect(conflictCopies(), ['# a\nmine']);
      },
    );

    test('keeps edits as a conflict copy if the note was deleted', () async {
      file().deleteSync();
      session.edit('# a\nmine');
      await session.flush();

      expect(await session.secure(), isTrue);
      expect(file().existsSync(), isFalse);
      expect(conflictCopies(), ['# a\nmine']);
    });

    test('keeps nothing for a deleted note without edits', () async {
      file().deleteSync();
      session.onRescan(null, scannedAt: later);

      expect(await session.secure(), isTrue);
      expect(dir.listSync(), isEmpty);
    });

    test('takes no edits once it keeps them as a conflict', () async {
      await editElsewhere('# a\ntheirs, longer');
      session
        ..edit('# a\nmine')
        ..addListener(() {
          if (session.state == EditState.keptAsConflict) {
            session.edit('# a\ntoo late');
          }
        });

      await session.secure();

      expect(session.text, '# a\nmine');
      expect(conflictCopies(), ['# a\nmine']);
    });

    test('reports edits that can be kept nowhere', () async {
      // Too long for a conflict copy's name: 251 bytes + its marker.
      final name = '${'x' * 248}.md';
      File('${dir.path}/$name').writeAsStringSync('# x');
      final long = (await files.reload(
        Note(
          folder: note.folder,
          path: path(name),
          file: note.file,
          version: note.version,
          modified: note.modified,
        ),
      )).value;
      final drafts = tempDrafts();
      final longSession = NoteEditSession(
        long,
        files,
        drafts,
        saveDelay: Duration.zero,
      );
      addTearDown(longSession.dispose);
      File('${dir.path}/$name').writeAsStringSync('# x\ntheirs');
      longSession.edit('# x\nmine');

      expect(await longSession.secure(), isFalse);
      expect(longSession.state, EditState.changedElsewhere);
      expect(conflictCopies(), isEmpty);
      // Kept on the device for the next start.
      final kept = await drafts.all(before: later);
      expect([for (final draft in kept) draft.text], ['# x\nmine']);
    });

    test('keeps edits only once', () async {
      await editElsewhere('# a\ntheirs, longer');
      session.edit('# a\nmine');

      await Future.wait([session.secure(), session.secure()]);
      session.edit('# a\nignored');
      await session.secure();

      expect(conflictCopies(), ['# a\nmine']);
    });
  });

  group('on the device first', () {
    late NoteDrafts drafts;
    late NoteEditSession staged;

    setUp(() {
      drafts = tempDrafts();
      staged = NoteEditSession(
        note,
        files,
        drafts,
        saveDelay: Duration.zero,
        publishDelay: const Duration(hours: 1),
      );
      addTearDown(staged.dispose);
    });

    Future<List<String>> draftTexts() async => [
      for (final draft in await drafts.all(before: later)) draft.text,
    ];

    /// Lets the save timer fire and the draft be written or removed.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    test('keeps edits on the device, not yet in the file', () async {
      staged.edit('# a\nmine');
      await settle();

      expect(staged.state, EditState.savedOnDevice);
      expect(onDisk(), '# a\n');
      final draft = (await drafts.all(before: later)).single;
      expect(draft.text, '# a\nmine');
      expect(draft.base, '# a\n');
      expect(draft.path, note.path);
    });

    test('writes the file after the publish delay', () async {
      final soon = NoteEditSession(
        note,
        files,
        drafts,
        saveDelay: Duration.zero,
        publishDelay: const Duration(milliseconds: 10),
      );
      addTearDown(soon.dispose);
      soon.edit('# a\nmine');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(onDisk(), '# a\nmine');
      expect(soon.state, EditState.saved);
      expect(await draftTexts(), isEmpty);
    });

    test('secure writes the file and drops the draft', () async {
      staged.edit('# a\nmine');
      await settle();

      expect(await staged.secure(), isTrue);

      expect(onDisk(), '# a\nmine');
      expect(staged.state, EditState.saved);
      expect(await draftTexts(), isEmpty);
    });

    test('a change elsewhere keeps the draft and asks', () async {
      staged.edit('# a\nmine');
      await settle();
      final theirs = await editElsewhere('# a\ntheirs');

      staged.onRescan(theirs, scannedAt: later);

      expect(staged.state, EditState.changedElsewhere);
      expect(await draftTexts(), ['# a\nmine']);
    });

    test('load theirs drops the draft', () async {
      staged.edit('# a\nmine');
      await settle();
      staged.onRescan(await editElsewhere('# a\ntheirs'), scannedAt: later);

      staged.loadTheirs();
      await settle();

      expect(await draftTexts(), isEmpty);
    });

    test('discard drops the edits and the draft', () async {
      staged.edit('# a\nmine');
      await settle();

      staged.discard();
      await settle();

      expect(staged.text, '# a\n');
      expect(staged.state, EditState.saved);
      expect(await draftTexts(), isEmpty);
      expect(await staged.secure(), isTrue);
      expect(onDisk(), '# a\n');
    });

    test('writes the file right away if the device cannot keep it', () async {
      final blocker = File('${tempFolder().path}/file')..writeAsStringSync('');
      final broken = NoteEditSession(
        note,
        files,
        NoteDrafts(Directory(blocker.path)),
        saveDelay: Duration.zero,
        publishDelay: const Duration(hours: 1),
      );
      addTearDown(broken.dispose);

      broken.edit('# a\nmine');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(onDisk(), '# a\nmine');
      expect(broken.state, EditState.saved);
    });
  });
}
