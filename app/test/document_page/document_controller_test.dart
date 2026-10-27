import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/document_page/document_controller.dart';

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
    return DocumentController(session, reachSettled: () async => reach);
  }

  test('edits saved in the file are kept', () async {
    final session = fixture.session()..type('mine ');
    final controller = DocumentController(
      session,
      reachSettled: () async => reach,
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
}
