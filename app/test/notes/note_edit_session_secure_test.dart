import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';

import '../support.dart';
import 'note_edit_session_fixture.dart';

/// Securing a session's edits before the note closes.
void main() {
  late EditSessionFixture fx;

  setUp(() async => fx = await EditSessionFixture.create());

  group('secure', () {
    test('saves pending edits as usual', () async {
      fx.session.edit('# a\nmine');

      expect(await fx.session.secure(), isTrue);
      expect(fx.onDisk(), '# a\nmine');
      expect(fx.conflictCopies(), isEmpty);
    });

    test(
      'keeps edits as a conflict copy if the note changed elsewhere',
      () async {
        await fx.editElsewhere('# a\ntheirs, longer');
        fx.session.edit('# a\nmine');

        expect(await fx.session.secure(), isTrue);
        expect(fx.session.state, EditState.keptAsConflict);
        expect(fx.onDisk(), '# a\ntheirs, longer');
        expect(fx.conflictCopies(), ['# a\nmine']);
      },
    );

    test('keeps edits as a conflict copy if the note was deleted', () async {
      fx.file().deleteSync();
      fx.session.edit('# a\nmine');
      await fx.session.flush();

      expect(await fx.session.secure(), isTrue);
      expect(fx.file().existsSync(), isFalse);
      expect(fx.conflictCopies(), ['# a\nmine']);
    });

    test('keeps nothing for a deleted note without edits', () async {
      fx.file().deleteSync();
      fx.session.rescanNow(null);

      expect(await fx.session.secure(), isTrue);
      expect(fx.dir.listSync(), isEmpty);
    });

    test('takes no edits once it keeps them as a conflict', () async {
      final session = fx.session;
      await fx.editElsewhere('# a\ntheirs, longer');
      session
        ..edit('# a\nmine')
        ..addListener(() {
          if (session.state == EditState.keptAsConflict) {
            session.edit('# a\ntoo late');
          }
        });

      await session.secure();

      expect(session.text, '# a\nmine');
      expect(fx.conflictCopies(), ['# a\nmine']);
    });

    test('reports edits that can be kept nowhere', () async {
      // Too long for a conflict copy's name: 251 bytes + its marker.
      final name = '${'x' * 248}.md';
      final note = fx.note;
      File('${fx.dir.path}/$name').writeAsStringSync('# x');
      final long = (await fx.files.reload(
        Note(
          folder: note.folder,
          path: path(name),
          file: note.file,
          version: note.version,
          modified: note.modified,
        ),
      )).value;
      final drafts = tempDrafts();
      final longSession = fx.open(note: long, drafts: drafts);
      File('${fx.dir.path}/$name').writeAsStringSync('# x\ntheirs');
      longSession.edit('# x\nmine');

      expect(await longSession.secure(), isFalse);
      expect(longSession.state, EditState.changedElsewhere);
      expect(fx.conflictCopies(), isEmpty);
      // Kept on the device for the next start.
      final kept = await drafts.all(before: fx.later);
      expect([for (final draft in kept) draft.text], ['# x\nmine']);
    });

    test('keeps edits only once', () async {
      await fx.editElsewhere('# a\ntheirs, longer');
      fx.session.edit('# a\nmine');

      await Future.wait([fx.session.secure(), fx.session.secure()]);
      fx.session.edit('# a\nignored');
      await fx.session.secure();

      expect(fx.conflictCopies(), ['# a\nmine']);
    });
  });
}
