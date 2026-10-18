import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_edit_session.dart';

import '../support.dart';
import 'note_edit_session_fixture.dart';

/// A session's edits meeting a change or delete from elsewhere.
void main() {
  late EditSessionFixture fx;

  setUp(() async => fx = await EditSessionFixture.create());

  test('asks before overwriting a change from elsewhere', () async {
    await fx.editElsewhere('# a\ntheirs, longer');
    fx.session.edit('# a\nmine');
    await fx.session.flush();

    expect(fx.session.state, EditState.changedElsewhere);
    expect(fx.onDisk(), '# a\ntheirs, longer');
  });

  test('a change elsewhere to the same text is not a conflict', () async {
    await fx.editElsewhere('# a\nsame');
    fx.session.edit('# a\nsame');
    await fx.session.flush();

    expect(fx.session.state, EditState.saved);
  });

  test('a rescan finding the same text is not a conflict', () async {
    final waiting = fx.open(saveDelay: const Duration(hours: 1));
    waiting.edit('# a\nsame');
    final theirs = await fx.editElsewhere('# a\nsame');

    waiting.rescanNow(theirs);

    expect(waiting.state, EditState.saved);
    expect(waiting.note.version, theirs.version);
  });

  test('keep mine overwrites the change from elsewhere', () async {
    await fx.editElsewhere('# a\ntheirs, longer');
    fx.session.edit('# a\nmine');
    await fx.session.flush();

    await fx.session.keepMine(fx.session.theirs!);

    expect(fx.onDisk(), '# a\nmine');
    expect(fx.session.state, EditState.saved);
  });

  test('keep mine asks again if the file changed once more', () async {
    await fx.editElsewhere('# a\ntheirs, longer');
    fx.session.edit('# a\nmine');
    await fx.session.flush();
    await fx.editElsewhere('# a\ntheirs, even longer');

    await fx.session.keepMine(fx.session.theirs!);
    expect(fx.session.state, EditState.changedElsewhere);
    expect(fx.onDisk(), '# a\ntheirs, even longer');

    await fx.session.keepMine(fx.session.theirs!);
    expect(fx.onDisk(), '# a\nmine');
  });

  test('keep mine and load theirs back up both versions first', () async {
    final session = fx.session;
    for (final (name, keep) in [
      ('keep mine', () => session.keepMine(session.theirs!)),
      ('load theirs', () => session.loadTheirs(session.theirs!)),
    ]) {
      fx.clearBackups();
      session.edit('# a\nmine, $name');
      session.rescanNow(await fx.editElsewhere('# a\ntheirs, $name'));

      expect(await keep(), PickResult.done);

      expect(fx.backedUp(), [
        'current: # a\ntheirs, $name',
        'other: # a\nmine, $name',
      ], reason: name);
    }
  });

  test('keeps both if no backup can be made', () async {
    fx.session.edit('# a\nmine');
    fx.session.rescanNow(await fx.editElsewhere('# a\ntheirs'));
    fx.blockBackups();

    final theirs = fx.session.theirs!;
    expect(await fx.session.keepMine(theirs), PickResult.noBackup);
    expect(await fx.session.loadTheirs(theirs), PickResult.noBackup);

    expect(fx.session.state, EditState.changedElsewhere);
    expect(fx.session.text, '# a\nmine');
    expect(fx.onDisk(), '# a\ntheirs');
    fx.unblockBackups();
  });

  test('tells of a newer change from elsewhere while asking', () async {
    fx.session.edit('# a\nmine');
    fx.session.rescanNow(await fx.editElsewhere('# a\ntheirs'));
    expect(fx.session.state, EditState.changedElsewhere);
    var told = 0;
    fx.session.addListener(() => told++);

    final newer = await fx.editElsewhere('# a\ntheirs, newer');
    fx.session.rescanNow(newer);

    expect(told, 1);
    expect(fx.session.theirs?.file.text, '# a\ntheirs, newer');
  });

  test('keep mine never saves over a version the user did not see', () async {
    fx.session.edit('# a\nmine');
    fx.session.rescanNow(await fx.editElsewhere('# a\ntheirs'));
    final seen = fx.session.theirs!;
    fx.session.rescanNow(await fx.editElsewhere('# a\nnewer'));

    expect(await fx.session.keepMine(seen), PickResult.newerVersion);
    expect(await fx.session.loadTheirs(seen), PickResult.newerVersion);

    expect(fx.session.state, EditState.changedElsewhere);
    expect(fx.onDisk(), '# a\nnewer');
    expect(fx.session.text, '# a\nmine');
  });

  test('load theirs asks again if a newer version comes during the '
      'backup', () async {
    final held = heldTempStore();
    final slow = fx.sessionBackingUpTo(held);
    slow.edit('# a\nmine');
    slow.rescanNow(await fx.editElsewhere('# a\ntheirs'));

    final picking = slow.loadTheirs(slow.theirs!);
    await held.reached.future;
    slow.rescanNow(await fx.editElsewhere('# a\nnewer'));
    held.release.complete();

    expect(await picking, PickResult.newerVersion);
    expect(slow.state, EditState.changedElsewhere);
    expect(slow.text, '# a\nmine');
  });

  test('load theirs drops the edits', () async {
    await fx.editElsewhere('# a\ntheirs, longer');
    fx.session.edit('# a\nmine');
    await fx.session.flush();

    expect(await fx.session.loadTheirs(fx.session.theirs!), PickResult.done);

    expect(fx.session.text, '# a\ntheirs, longer');
    expect(fx.session.state, EditState.saved);
  });

  test('stops saving a note deleted elsewhere', () async {
    fx.file().deleteSync();
    fx.session.edit('# a\nkept');
    await fx.session.flush();

    expect(fx.session.state, EditState.deletedElsewhere);

    fx.session.edit('# a\nkept, more');
    await fx.session.flush();

    expect(fx.file().existsSync(), isFalse);
    expect(fx.session.text, '# a\nkept, more');
  });

  test('a rescan reports a note deleted elsewhere', () {
    fx.session.rescanNow(null);

    expect(fx.session.state, EditState.deletedElsewhere);
  });

  test('saves again once a note that looked deleted is back', () async {
    fx.session.rescanNow(null);
    fx.session.edit('# a\nmine');

    fx.session.rescanNow(fx.note);
    await fx.session.flush();

    expect(fx.session.state, EditState.saved);
    expect(fx.onDisk(), '# a\nmine');
  });

  test('shows a note back with other text if there were no edits', () async {
    fx.session.rescanNow(null);
    final theirs = await fx.editElsewhere('# a\ntheirs');

    fx.session.rescanNow(theirs);

    expect(fx.session.state, EditState.saved);
    expect(fx.session.text, '# a\ntheirs');
  });

  test('a note back with other text is a change from elsewhere', () async {
    fx.session.rescanNow(null);
    fx.session.edit('# a\nmine');
    final theirs = await fx.editElsewhere('# a\ntheirs');

    fx.session.rescanNow(theirs);

    expect(fx.session.state, EditState.changedElsewhere);
  });

  /// Deletes the note's file under unsaved edits.
  Future<void> deleteUnderEdits() async {
    fx.file().deleteSync();
    fx.session.edit('# a\nkept');
    await fx.session.flush();
  }

  test('restore mine writes the text again', () async {
    await deleteUnderEdits();

    await fx.session.restoreMine();

    expect(fx.onDisk(), '# a\nkept');
    expect(fx.session.state, EditState.saved);
  });

  test('restore mine of a note back with the same text is done', () async {
    await deleteUnderEdits();
    fx.file().writeAsStringSync('# a\nkept');

    await fx.session.restoreMine();

    expect(fx.session.state, EditState.saved);
    expect(fx.onDisk(), '# a\nkept');
  });

  test('restore mine of a note back with other text asks', () async {
    await deleteUnderEdits();
    fx.file().writeAsStringSync('# a\ntheirs');

    await fx.session.restoreMine();

    expect(fx.session.state, EditState.changedElsewhere);
    expect(fx.session.theirs?.file.text, '# a\ntheirs');
    expect(fx.onDisk(), '# a\ntheirs');
  });

  test('restore mine tapped twice restores once', () async {
    await deleteUnderEdits();

    await Future.wait([fx.session.restoreMine(), fx.session.restoreMine()]);

    expect(fx.onDisk(), '# a\nkept');
    expect(fx.session.state, EditState.saved);
  });
}
