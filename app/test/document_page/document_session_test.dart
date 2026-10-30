import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode, EditText;

import '../support.dart';
import 'document_fixture.dart';
import 'markdown_session.dart';

void main() {
  late DocumentFixture fixture;

  setUp(() async => fixture = await DocumentFixture.create());

  test('securing writes the edits into the file', () async {
    final session = fixture.session()..type('x');

    expect(await session.secure(.hide), isTrue);

    expect(fixture.onDisk('a.md'), 'xone\n');
    expect(session.status, isA<InStep>());
    expect(session.saveState, SaveState.inFolder);
    await eventually(() async => (await fixture.draftsIn('f1')).isEmpty);
  });

  test("a new document's file is created once secured, named after its "
      'first line', () async {
    final session = fixture.session(fixture.newFile)..type('Milk');
    expect(fixture.onDisk('Milk.md'), isNull);

    expect(await session.secure(.close), isTrue);

    expect(fixture.onDisk('Milk.md'), 'Milk\n');
    expect(session.document?.path, path('Milk.md'));
  });

  test('a bug in writing stops the session; edits stay a draft', () async {
    final errors = <Object>[];
    final notices = <bool>[];
    late DocumentSession session;

    // Made in the zone, so the error of its file owner is heard there.
    await runZonedGuarded(() async {
      session = markdownSession(
        fixture.document,
        FileEffects(
          filesOf: (_) => throw StateError('bug'),
          draftsOf: (folder) => fixture.drafts[folder.id]!,
          create: (
            _, {
            required type,
            required title,
            required text,
            newSubfolder = false,
          }) => throw StateError('bug'),
          moveDocument: (_, _, {required title, required newSubfolder}) =>
              throw StateError('bug'),
        ),
      );
      session
        ..stopNotices.listen(notices.add)
        ..type('mine ');
      expect(await session.secure(.hide), isFalse);
      await pumpEventQueue();
    }, (error, _) => errors.add(error));
    addTearDown(session.dispose);

    expect(errors.single, isA<StateError>());
    expect(session.state, isA<Stopped>());
    expect(fixture.onDisk('a.md'), 'one\n');
    await eventually(
      () async =>
          (await fixture.draftsIn('f1')).singleOrNull?.text == 'mine one\n',
    );
    // Told once, as it is known that the edits are kept.
    await eventually(() async => notices.isNotEmpty);
    expect(notices, [true]);
    expect(session.state, isA<Stopped>().having((s) => s.kept, 'kept', true));
  });

  test('once stopped, its text is the latest edits, also those the editor '
      'still held', () async {
    var broken = false;
    late DocumentSession session;

    await runZonedGuarded(() async {
      session = markdownSession(
        fixture.document,
        FileEffects(
          filesOf: (folder) =>
              broken ? throw StateError('bug') : fixture.files[folder.id]!,
          draftsOf: (folder) => fixture.drafts[folder.id]!,
          create: (
            _, {
            required type,
            required title,
            required text,
            newSubfolder = false,
          }) => throw StateError('bug'),
          moveDocument: (_, _, {required title, required newSubfolder}) =>
              throw StateError('bug'),
        ),
      )..type('a ');
      // Sent at the typing pause: kept as a draft, not yet in the file.
      await eventually(() async => !session.editor.state.unsent);
      broken = true;
      session
        ..type('mine ')
        ..saveNow();
      await eventually(() => session.state is Stopped);
    }, (_, _) {});
    addTearDown(session.dispose);

    expect(session.state, isA<Stopped>());
    expect(session.text, 'a mine one\n');
  });

  test("a new document's title and path follow its saves, not each "
      'keystroke', () async {
    final session = fixture.session(fixture.newFile);
    final before = (session.title, session.path);

    session.type('Milk');
    expect((session.title, session.path), before);

    session.saveNow();
    await eventually(() => session.title == 'Milk');
    expect(session.path, path('Milk.md'));
  });

  test('in Markdown edit, the title follows a save too', () async {
    final session = markdownSession(
      null,
      fixture.effects(fixture.newFile),
      mode: EditMode.markdown,
    );
    addTearDown(session.dispose);

    session.gate.send((now) => EditText('# Milk', revision: now.revision));
    session.saveNow();

    await eventually(() => session.title == 'Milk');
    expect(session.path, path('Milk.md'));
  });

  test('a change elsewhere as the first change tells the new title', () async {
    final session = fixture.session();
    final titles = <String>[];
    session.changes.listen((_) => titles.add(session.title));
    final theirs = await fixture.editElsewhere('# Two\n');

    session.observe(contentsFinding([theirs.document]));

    await eventually(() => titles.contains('Two'));
  });

  test("a new document's draft is named after its latest save", () async {
    Future<bool> draftAt(String name) async =>
        (await fixture.draftsIn('f1')).singleOrNull?.path == path(name);
    final session = fixture.session(fixture.newFile)..type('Milk');
    // Sent at the typing pause: kept as a draft, not yet in a file.
    await eventually(() => draftAt('Milk.md'));

    session.type('y');

    await eventually(() => draftAt('Milky.md'));
    expect(fixture.onDisk('Milky.md'), isNull);
  });

  test(
    "once stopped, a new document's draft is named after its edits",
    () async {
      late DocumentSession session;

      await runZonedGuarded(() async {
        session = markdownSession(
          null,
          FileEffects(
            newFile: fixture.newFile,
            filesOf: (folder) => fixture.files[folder.id]!,
            draftsOf: (folder) => fixture.drafts[folder.id]!,
            create: (
              _, {
              required type,
              required title,
              required text,
              newSubfolder = false,
            }) => throw StateError('bug'),
            moveDocument: (_, _, {required title, required newSubfolder}) =>
                throw StateError('bug'),
          ),
        )..type('Milk');
        await session.secure(.close);
        await eventually(() => session.state is Stopped);
      }, (_, _) {});
      addTearDown(session.dispose);

      await eventually(
        () async =>
            (await fixture.draftsIn('f1')).singleOrNull?.path ==
            path('Milk.md'),
      );
    },
  );

  test('typing tells of the edits being edited, at once', () {
    final session = fixture.session(fixture.newFile);
    final states = <SaveState>[];
    session.changes.listen((_) => states.add(session.saveState));

    session.type('x');

    expect(states, [SaveState.editing]);
  });

  test('an empty new document is never written', () async {
    final session = fixture.session(fixture.newFile);

    expect(await session.secure(.close), isTrue);

    expect(fixture.dirs[0].listSync().map((file) => file.path), [
      '${fixture.dirs[0].path}/a.md',
    ]);
    expect(session.saveState, SaveState.none);
  });

  test('a new subfolder the user asked for is made with the first write '
      'into it, never for an empty new document', () async {
    NewFile intoNew() => NewFile(
      (folder: fixture.folders[0], subfolder: path('2026')),
      type: appDocumentTypes().forNew,
      newSubfolder: true,
    );
    final empty = fixture.session(intoNew());
    expect(await empty.secure(.close), isTrue);
    expect(Directory('${fixture.dirs[0].path}/2026').existsSync(), isFalse);

    final session = fixture.session(intoNew())..type('Milk');
    expect(await session.secure(.close), isTrue);

    expect(fixture.onDisk('2026/Milk.md'), 'Milk\n');
  });

  test('a change elsewhere without edits shows, and says so', () async {
    final session = fixture.session();
    final notices = <FileEvent>[];
    session.fileNotices.listen(notices.add);
    final theirs = await fixture.editElsewhere('two\n');

    session.observe(contentsFinding([theirs.document]));

    await eventually(() => notices.isNotEmpty);
    expect(notices.single, isA<Replaced>());
    expect(session.text, 'two\n');
    expect(session.document?.text, 'two\n');
  });

  test(
    'a listing of the version it holds reads nothing and says nothing',
    () async {
      final reads = <Object>[];
      final session = fixture.session()..fileNotices.listen(reads.add);

      session.observe(contentsFinding([fixture.document.document]));
      await pumpEventQueue();

      expect(reads, isEmpty);
      expect(session.status, isA<InStep>());
    },
  );

  test('a scan in which the folder failed says nothing of the file', () {
    final session = fixture.session();

    session.observe(
      contentsFinding(const [], failed: {fixture.folders[0]: .ioFailure}),
    );

    expect(session.status, isA<InStep>());
  });

  test('a scan that could not read a subfolder above the file says nothing '
      'of it', () async {
    Directory('${fixture.dirs[0].path}/sub').createSync();
    final inSub = (await fixture.files['f1']!.create(
      'b',
      type: appDocumentTypes().forNew,
      text: '# b\n',
      subfolder: path('sub'),
    )).value;
    final session = fixture.session(ExistingFile(inSub));

    session.observe(
      contentsFinding(
        const [],
        folders: fixture.folders,
        unreadable: {
          'f1': [path('sub')],
        },
      ),
    );

    expect(session.status, isA<InStep>());
  });

  test('a scan in which no folder shows the file any more says nothing of '
      'it', () {
    final session = fixture.session();
    final narrowed = fixture.folders[0].copyWith(
      selection: Selection.of([path('elsewhere')]),
    );

    session.observe(contentsFinding(const [], folders: [narrowed]));

    expect(session.status, isA<InStep>());
  });

  test('a new document has nothing to find in scans', () {
    final session = fixture.session(fixture.newFile);

    session.observe(contentsFinding(const []));

    expect(session.status, isA<Unwritten>());
  });

  group('changed elsewhere during edits', () {
    late Seen theirs;

    Future<void> changeDuringEdits(DocumentSession session) async {
      session.type('x');
      theirs = (await fixture.editElsewhere('two\n')).seen;
      expect(await session.secure(.hide), isTrue);
      expect(session.status, isA<ChangedElsewhere>());
      expect(session.saveState, SaveState.onDevice);
    }

    test('picking theirs shows them', () async {
      final session = fixture.session();
      await changeDuringEdits(session);

      session.pick(.theirs, theirs: theirs, rev: session.rev);

      await eventually(() => session.status is InStep);
      expect(session.text, 'two\n');
      expect(fixture.onDisk('a.md'), 'two\n');
    });

    test('picking mine writes the edits over theirs', () async {
      final session = fixture.session();
      await changeDuringEdits(session);

      session.pick(.mine, theirs: theirs, rev: session.rev);

      await eventually(() => fixture.onDisk('a.md') == 'xone\n');
    });
  });

  test('a file deleted elsewhere comes back with the edits', () async {
    final session = fixture.session()..type('x');
    File('${fixture.dirs[0].path}/a.md').deleteSync();
    await session.secure(.hide);
    expect(session.status, isA<DeletedElsewhere>());

    session.restoreMine();

    await eventually(() => fixture.onDisk('a.md') == 'xone\n');
  });

  test('a moved document goes on in its copy', () async {
    final session = fixture.session();

    final moved = await session.move((
      place: (folder: fixture.folders[1], subfolder: null),
      title: 'a',
      newSubfolder: false,
    ));
    session.type('x');
    await session.secure(.hide);

    expect(moved, isA<Ok<DocumentText, MoveFailure>>());
    expect(fixture.onDisk('a.md'), isNull);
    expect(fixture.onDisk('a.md', index: 1), 'xone\n');
  });

  test(
    'a move with unsaved edits, then leaving at once, takes them along',
    () async {
      final session = fixture.session()..type('x');
      // The edits are kept as a draft on this device first.
      await eventually(() async => (await fixture.draftsIn('f1')).isNotEmpty);

      final moved = session.move((
        place: (folder: fixture.folders[1], subfolder: null),
        title: 'a',
        newSubfolder: false,
      ));
      final kept = await session.secure(.close);

      expect(kept, isTrue);
      expect(await moved, isA<Ok<DocumentText, MoveFailure>>());
      expect(fixture.onDisk('a.md'), isNull);
      expect(fixture.onDisk('a.md', index: 1), 'xone\n');
      await eventually(() async => (await fixture.draftsIn('f1')).isEmpty);
      expect(await fixture.draftsIn('f2'), isEmpty);
    },
  );
}
