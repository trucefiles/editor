import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document_session.dart';
import 'package:truce_editor/documents/note_version.dart';
import 'package:truce_editor/documents/save_state.dart';

import '../support.dart' hide noteOf;
import 'document_fixture.dart';

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

    expect(fixture.onDisk('Milk.md'), 'Milk');
    expect(session.note?.path, path('Milk.md'));
  });

  test('an empty new document is never written', () async {
    final session = fixture.session(fixture.newFile);

    expect(await session.secure(.close), isTrue);

    expect(fixture.dirs[0].listSync().map((file) => file.path), [
      '${fixture.dirs[0].path}/a.md',
    ]);
    expect(session.saveState, SaveState.none);
  });

  test('a change elsewhere without edits shows, and says so', () async {
    final session = fixture.session();
    final notices = <FileOutput>[];
    session.fileNotices.listen(notices.add);
    final theirs = await fixture.editElsewhere('two\n');

    session.observe(fixture.scanFinding([theirs]));

    expect(notices.single, isA<Replaced>());
    expect(session.text, 'two\n');
    expect(session.note?.file.text, 'two\n');
  });

  test('a scan that cannot see the file says nothing of it', () async {
    final session = fixture.session();

    session.observe(fixture.scanFinding(const [], unread: {fixture.note.key}));

    expect(session.status, isA<InStep>());
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
    final copy = (await fixture.files['f2']!.copyIn(
      fixture.note,
      'one\n',
    )).value;

    session
      ..moved(copy)
      ..type('x');
    await session.secure(.hide);

    expect(fixture.onDisk('a.md', index: 1), 'xone\n');
  });
}
