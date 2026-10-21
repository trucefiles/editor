import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_edit_session.dart';

import '../support.dart';
import 'note_edit_session_fixture.dart';

/// A session keeping edits on the device before it writes the file.
void main() {
  late EditSessionFixture fx;

  setUp(() async => fx = await EditSessionFixture.create());

  group('on the device first', () {
    late NoteDrafts drafts;
    late NoteEditSession staged;

    setUp(() {
      drafts = tempDrafts();
      staged = fx.open(drafts: drafts, publishDelay: const Duration(hours: 1));
    });

    Future<List<String>> draftTexts() async => [
      for (final draft in await drafts.all(before: fx.later)) draft.text,
    ];

    /// Waits until the drafts on the device hold [texts]: they are
    /// written and removed after a timer.
    Future<void> draftsBecome(List<String> texts) => eventually(
      () async =>
          const ListEquality<String>().equals(await draftTexts(), texts),
    );

    /// Edits the staged note and waits until its draft is written.
    Future<void> stageMine() async {
      staged.edit('# a\nmine');
      await eventually(() => staged.state == EditState.savedOnDevice);
    }

    test('keeps edits on the device, not yet in the file', () async {
      await stageMine();

      expect(staged.state, EditState.savedOnDevice);
      expect(fx.onDisk(), '# a\n');
      final draft = (await drafts.all(before: fx.later)).single;
      expect(draft.text, '# a\nmine');
      expect(draft.base, '# a\n');
      expect(draft.path, fx.note.path);
    });

    test('writes the file after the publish delay', () async {
      final soon = fx.open(
        drafts: drafts,
        publishDelay: const Duration(milliseconds: 10),
      );
      soon.edit('# a\nmine');

      await eventually(() => soon.state == EditState.saved);
      await draftsBecome([]);

      expect(fx.onDisk(), '# a\nmine');
    });

    test('secure writes the file and drops the draft', () async {
      await stageMine();

      expect(await staged.secure(), isTrue);

      expect(fx.onDisk(), '# a\nmine');
      expect(staged.state, EditState.saved);
      await draftsBecome([]);
    });

    test('a change elsewhere keeps the draft and asks', () async {
      await stageMine();
      final theirs = await fx.editElsewhere('# a\ntheirs');

      staged.rescanNow(theirs);

      expect(staged.state, EditState.changedElsewhere);
      expect(await draftTexts(), ['# a\nmine']);
    });

    test('keeps edits made while changed or deleted elsewhere', () async {
      await stageMine();
      staged.rescanNow(await fx.editElsewhere('# a\ntheirs'));

      staged.edit('# a\nmine, more');
      await draftsBecome(['# a\nmine, more']);

      fx.file().deleteSync();
      staged.rescanNow(null);
      staged.edit('# a\nmine, even more');
      await draftsBecome(['# a\nmine, even more']);

      expect(staged.state, EditState.deletedElsewhere);
      expect(fx.file().existsSync(), isFalse);
    });

    test('drops the draft once the edits are undone while deleted '
        'elsewhere', () async {
      await stageMine();
      fx.file().deleteSync();
      staged.rescanNow(null);

      staged.edit('# a\n');

      await draftsBecome([]);
    });

    test('load theirs drops the draft', () async {
      await stageMine();
      staged.rescanNow(await fx.editElsewhere('# a\ntheirs'));

      await staged.loadTheirs(staged.theirs!);

      await draftsBecome([]);
    });

    test('discard drops the edits and the draft', () async {
      await stageMine();

      staged.discard();
      await draftsBecome([]);

      expect(staged.text, '# a\n');
      expect(staged.state, EditState.saved);
      expect(await staged.secure(), isTrue);
      expect(fx.onDisk(), '# a\n');
    });

    test('writes the file right away if the device cannot keep it', () async {
      final blocker = File('${tempFolder().path}/file')..writeAsStringSync('');
      final broken = fx.open(
        drafts: NoteDrafts(Directory(blocker.path)),
        publishDelay: const Duration(hours: 1),
      );

      broken.edit('# a\nmine');

      await eventually(() => broken.state == EditState.saved);

      expect(fx.onDisk(), '# a\nmine');
      expect(broken.state, EditState.saved);
    });
  });
}
