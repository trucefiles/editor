import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/document_page/document_controller.dart';
import 'package:truce_editor/document_page/document_file.dart';
import 'package:truce_editor/document_page/document_session.dart';
import 'package:truce_editor/document_page/file_effects.dart';
import 'package:truce_editor/documents/delete_failure.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_test_support/truce_test_support.dart';

import '../support.dart' show eventually;
import 'document_fixture.dart';

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
    bool canEdit = true,
    DeleteDocument? delete,
  }) {
    final controller = DocumentController(
      session,
      mode: EditMode.read,
      reachSettled: () async => reach,
      backUp: backUp ?? (_) async => const Ok(null),
      canEdit: () => canEdit,
      delete:
          delete ??
          (document, text) async => Ok((
            document: document,
            text: text,
            mark: DocumentMark.none,
            settings: DocumentSettings.defaults,
          )),
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

      expect(await controller.deleteDocument(), isA<DocumentDeleted>());
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

  group('the mode picked', () {
    test('is remembered at once', () {
      final controller = controllerOn(fixture.session())
        ..pickMode(EditMode.markdown);

      expect(controller.mode, EditMode.markdown);
      expect(settings[fixture.document.key]?.mode, EditMode.markdown);
    });

    test('is remembered once a new document has a file', () async {
      final controller = controllerOn(fixture.session(fixture.newFile))
        ..pickMode(EditMode.markdown);
      expect(settings, isEmpty);

      controller.session.type('new');
      final document = (await controller.withFile()).value;

      expect(settings[document.key]?.mode, EditMode.markdown);
    });
  });

  group('once the document stopped (a bug)', () {
    /// A controller on a session whose file owner stopped as it wrote.
    Future<DocumentController> stopped() async {
      late DocumentController controller;
      await runZonedGuarded(() async {
        final session = DocumentSession(
          FileEffects(
            ExistingFile(fixture.document),
            filesOf: (_) => throw StateError('bug'),
            draftsOf: (folder) => fixture.drafts[folder.id]!,
            create: (_, {required title, required text}) =>
                throw StateError('bug'),
          ),
        );
        addTearDown(session.dispose);
        controller = controllerOn(session, delete: (_, _) => fail('deleted'));
        session.type('mine ');
        await session.secure(.hide);
        await pumpEventQueue();
      }, (_, _) {});
      expect(controller.session.stopped, isTrue);
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
      await eventually(() async => controller.session.editsKept != null);

      expect(controller.session.editsKept, isTrue);
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
      session.gate.send((now) => Undo(revision: now.revision));
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
      final backedUp = <String>[];
      final controller = controllerOn(
        session,
        backUp: (text) async {
          backedUp.add(text);
          return const Ok(null);
        },
        canEdit: false,
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
