import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/document_page/document_controller.dart';
import 'package:truce_editor/document_page/document_session.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'document_fixture.dart';

void main() {
  late DocumentFixture fixture;
  var reach = Reach.reachable;

  setUp(() async {
    reach = Reach.reachable;
    fixture = await DocumentFixture.create();
  });

  /// A controller on the document with unsaved edits, its folder gone, so
  /// they can be kept nowhere in it.
  DocumentController editedInGoneFolder() {
    final session = fixture.session()..type('mine ');
    final dir = fixture.dirs[0];
    final away = dir.renameSync('${dir.path}-away');
    addTearDown(() => away.renameSync(dir.path));
    return DocumentController(
      session,
      reachSettled: () async => reach,
      backUp: (_) async => const Ok(null),
      canEdit: () => true,
    );
  }

  test('edits saved in the file are kept', () async {
    final session = fixture.session()..type('mine ');
    final controller = DocumentController(
      session,
      reachSettled: () async => reach,
      backUp: (_) async => const Ok(null),
      canEdit: () => true,
    );

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

  group('restoring a backup', () {
    test('backs up the text now, then shows the backup, undoable', () async {
      final session = fixture.session()..type('mine ');
      final backedUp = <String>[];
      final controller = DocumentController(
        session,
        reachSettled: () async => reach,
        backUp: (text) async {
          backedUp.add(text);
          return const Ok(null);
        },
        canEdit: () => true,
      );

      expect(await controller.restore('backup\n'), RestoreOutcome.restored);
      expect(backedUp, ['mine one\n']);
      expect(textShown(session), 'backup');
      session.gate.send((now) => Undo(revision: now.revision));
      expect(textShown(session), 'mine one');
    });

    test('changes nothing if the text now cannot be backed up', () async {
      final session = fixture.session()..type('mine ');
      final controller = DocumentController(
        session,
        reachSettled: () async => reach,
        backUp: (_) async => const Err(StoreError.ioFailure),
        canEdit: () => true,
      );

      expect(await controller.restore('backup\n'), RestoreOutcome.notBackedUp);
      expect(textShown(session), 'mine one');
    });

    test('changes nothing once the document cannot be edited', () async {
      final session = fixture.session()..type('mine ');
      final backedUp = <String>[];
      final controller = DocumentController(
        session,
        reachSettled: () async => reach,
        backUp: (text) async {
          backedUp.add(text);
          return const Ok(null);
        },
        canEdit: () => false,
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
