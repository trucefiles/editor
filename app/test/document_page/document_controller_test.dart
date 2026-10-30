import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/document_page/document_controller.dart';
import 'package:truce_markdown/truce_markdown.dart' hide Selection;
import 'package:truce_test_support/truce_test_support.dart';

import '../support.dart' show eventually;
import 'document_fixture.dart';
import 'markdown_session.dart';

/// A type's view settings, opaque to the page.
final _view = ViewSettings({'mode': 'markdown'});

void main() {
  late DocumentFixture fixture;
  var reach = Reach.reachable;

  /// The settings edits the controller made, by document.
  final settings = <DocumentKey, DocumentSettings>{};

  setUp(() async {
    reach = Reach.reachable;
    settings.clear();
    fixture = await DocumentFixture.create();
  });

  /// A controller on [session], in Read at first.
  DocumentController controllerOn(
    DocumentSession session, {
    BackUpText? backUp,
    DeleteForUndo? delete,
  }) {
    final controller = DocumentController(
      session,
      reach: () => reach,
      reachSettled: () async => reach,
      backUp: backUp ?? (_) async => const Ok(null),
      delete:
          delete ??
          (document, text) async => Ok((
            document: document,
            text: text,
            mark: DocumentMark.none,
            settings: DocumentSettings.defaults,
          )),
      settingsOf: (key) => settings[key] ?? DocumentSettings.defaults,
      editSettings: (key, change) async =>
          settings[key] = change(settings[key] ?? DocumentSettings.defaults),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  /// A controller on the document with unsaved edits, its folder gone, so
  /// they can be kept nowhere in it.
  DocumentController editedInGoneFolder() {
    final session = fixture.session()..type('mine ');
    final dir = fixture.dirs[0];
    final away = dir.renameSync('${dir.path}-away');
    addTearDown(() => away.renameSync(dir.path));
    return controllerOn(session);
  }

  test('listeners hear of each change of the session, at once', () {
    final session = fixture.session(fixture.newFile);
    final controller = controllerOn(session);
    final states = <SaveState>[];
    controller.addListener(() => states.add(session.saveState));

    session.type('x');

    expect(states, [SaveState.editing]);
  });

  test('stops hearing of the session once disposed', () {
    final session = fixture.session(fixture.newFile);
    DocumentController(
      session,
      reach: () => reach,
      reachSettled: () async => reach,
      backUp: (_) async => const Ok(null),
      delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
      settingsOf: (_) => DocumentSettings.defaults,
      editSettings: (_, _) async {},
    ).dispose();

    // A notifier told after its dispose fails.
    session.type('x');

    expect(session.saveState, SaveState.editing);
  });

  group('what the screen shows', () {
    test('read only while the folder is unreachable, told as it changes', () {
      final controller = controllerOn(fixture.session());
      var told = 0;
      controller.addListener(() => told++);
      expect(controller.readOnly, isFalse);

      reach = Reach.unreachable;
      controller.reachChanged();

      expect(
        (controller.readOnly, controller.unreachable, told),
        (true, true, 1),
      );
    });

    test('leaves at once only with nothing left to keep', () async {
      final session = fixture.session();
      final controller = controllerOn(session);
      expect(controller.canLeaveNow, isTrue);

      session.type('x');

      expect(controller.canLeaveNow, isFalse);
      await session.secure(.hide);
      expect(controller.canLeaveNow, isTrue);
    });

    test("the document's settings; the defaults while it has no file", () {
      final pinned = DocumentSettings.defaults.withPinned(pinned: true);
      settings[fixture.document.key] = pinned;

      expect(controllerOn(fixture.session()).settings, pinned);
      expect(
        controllerOn(fixture.session(fixture.newFile)).settings,
        DocumentSettings.defaults,
      );
    });

    test('whether the folders still show the document', () {
      final controller = controllerOn(fixture.session());
      final shown = fixture.folders[0];

      expect(controller.shownIn(fixture.folders), DocumentShown.shown);
      expect(
        controller.shownIn([
          shown.copyWith(selection: Selection.of([RelPath.parse('sub')!])),
        ]),
        DocumentShown.narrowedAway,
      );
      expect(
        controller.shownIn([fixture.folders[1]]),
        DocumentShown.folderRemoved,
      );
    });
  });

  test('edits saved in the file are kept', () async {
    final controller = controllerOn(fixture.session()..type('mine '));

    expect(await controller.keep(.close), isTrue);
    expect(
      File('${fixture.dirs[0].path}/a.md').readAsStringSync(),
      'mine one\n',
    );
  });

  test(
    'edits are kept on the device while the folder is unreachable',
    () async {
      reach = Reach.unreachable;

      expect(await editedInGoneFolder().keep(.close), isTrue);
    },
  );

  test('edits are not kept if the folder can be reached', () async {
    reach = Reach.reachable;

    expect(await editedInGoneFolder().keep(.close), isFalse);
  });

  group('going', () {
    test('goes without asking once the edits are kept', () async {
      final controller = controllerOn(fixture.session()..type('mine '));

      expect(await controller.mayGo(.close, () => fail('asked')), isTrue);
    });

    test('edits kept nowhere: goes if the user drops them', () async {
      final controller = editedInGoneFolder();
      var asked = false;

      expect(await controller.mayGo(.close, () async => asked = true), isTrue);
      expect(asked, isTrue);
    });

    test('edits kept nowhere: stays if the user keeps them', () async {
      final controller = editedInGoneFolder();

      expect(await controller.mayGo(.close, () async => false), isFalse);
      expect(controller.session.text, 'mine one\n');
    });
  });

  group('deleting', () {
    test('deletes the document with every edit', () async {
      final deleted = <String>[];
      final controller = controllerOn(
        fixture.session()..type('mine '),
        delete: (document, text) async {
          deleted.add(text);
          return Ok((
            document: document,
            text: text,
            mark: DocumentMark.none,
            settings: DocumentSettings.defaults,
          ));
        },
      );

      expect(await controller.deleteDocument(), isA<DeletedForUndo>());
      expect(deleted, ['mine one\n']);
    });

    test('tells why the document stays', () async {
      final controller = controllerOn(
        fixture.session(),
        delete: (_, _) async => const Err(DeleteBlockedByConflict()),
      );

      expect(
        await controller.deleteDocument(),
        isA<DeleteRefused>().having(
          (outcome) => outcome.failure,
          'failure',
          isA<DeleteBlockedByConflict>(),
        ),
      );
    });

    test('drops a new document without a file', () async {
      final controller = controllerOn(
        fixture.session(fixture.newFile)..type('mine'),
        delete: (_, _) => fail('deleted'),
      );

      expect(await controller.deleteDocument(), isA<NewDropped>());
    });
  });

  group('the file for an action', () {
    test('is the document, with every edit sent', () async {
      final controller = controllerOn(fixture.session()..type('mine '));

      expect((await controller.withFile()).value.key, fixture.document.key);
      expect(fixture.onDisk('a.md'), 'mine one\n');
    });

    test('is created first for a new document', () async {
      final controller = controllerOn(
        fixture.session(fixture.newFile)..type('new'),
      );

      expect((await controller.withFile()).value.path.value, 'new.md');
    });

    test('is none for an empty new document', () async {
      final controller = controllerOn(fixture.session(fixture.newFile));

      expect((await controller.withFile()).error, NoFile.empty);
    });
  });

  group('settings kept', () {
    test('are kept at once', () {
      controllerOn(fixture.session())
          .keepSettings((settings) => settings.withView(_view));

      expect(settings[fixture.document.key]?.view, _view);
    });

    test('are kept in order once a new document has a file', () async {
      final controller = controllerOn(fixture.session(fixture.newFile))
        ..keepSettings((settings) => settings.withView(_view))
        ..keepSettings((settings) => settings.withPinned(pinned: true));
      expect(settings, isEmpty);

      controller.session.type('new');
      final document = (await controller.withFile()).value;

      expect(settings[document.key]?.view, _view);
      expect(settings[document.key]?.pinned, isTrue);
    });
  });

  group('once the document stopped (a bug)', () {
    /// A controller on a session whose file owner stopped as it wrote.
    Future<DocumentController> stopped() async {
      late DocumentController controller;
      await runZonedGuarded(() async {
        final session = markdownSession(
          fixture.document,
          (summaries) => FileEffects(
            summaries: summaries,
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
        addTearDown(session.dispose);
        controller = controllerOn(session, delete: (_, _) => fail('deleted'));
        session.type('mine ');
        await session.secure(.hide);
        await pumpEventQueue();
      }, (_, _) {});
      expect(controller.session.state, isA<Stopped>());
      expect(controller.readOnly, isTrue);
      return controller;
    }

    test('it is not deleted', () async {
      final controller = await stopped();

      expect(await controller.deleteDocument(), isA<DocumentStopped>());
      expect(fixture.onDisk('a.md'), 'one\n');
    });

    test('nothing acts on its file', () async {
      final controller = await stopped();

      expect((await controller.withFile()).error, NoFile.stopped);
    });

    test('it goes as the edits are kept on this device', () async {
      final controller = await stopped();
      await eventually(
        () async => (controller.session.state as Stopped).kept != null,
      );

      expect((controller.session.state as Stopped).kept, isTrue);
      expect(await controller.mayGo(.close, () => fail('asked')), isTrue);
    });
  });

  group('restoring a backup', () {
    test('backs up the text now, then shows the backup, undoable', () async {
      final session = fixture.session()..type('mine ');
      final backedUp = <String>[];
      final controller = controllerOn(
        session,
        backUp: (text) async {
          backedUp.add(text);
          return const Ok(null);
        },
      );

      expect(await controller.restore('backup\n'), RestoreOutcome.restored);
      expect(backedUp, ['mine one\n']);
      expect(textShown(session), 'backup');
      session.editor.send(const Undo());
      expect(textShown(session), 'mine one');
    });

    test('changes nothing if the text now cannot be backed up', () async {
      final session = fixture.session()..type('mine ');
      final controller = controllerOn(
        session,
        backUp: (_) async => const Err(StoreError.ioFailure),
      );

      expect(await controller.restore('backup\n'), RestoreOutcome.notBackedUp);
      expect(textShown(session), 'mine one');
    });

    test('changes nothing once the document cannot be edited', () async {
      final session = fixture.session()..type('mine ');
      reach = Reach.unreachable;
      final backedUp = <String>[];
      final controller = controllerOn(
        session,
        backUp: (text) async {
          backedUp.add(text);
          return const Ok(null);
        },
      );

      expect(await controller.restore('backup\n'), RestoreOutcome.notEditable);
      expect(backedUp, isEmpty);
      expect(textShown(session), 'mine one');
    });
  });
}

/// The text the document's editor shows, its rows joined.
String textShown(DocumentSession session) => [
  for (final row in (session.gate.state.content as FormattedContent).view.rows)
    if (row case TextRow(:final leaf)) textOf(leaf).text,
].join('\n');
