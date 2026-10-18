import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/notes/note_edit_session.dart';

import '../support.dart';
import 'note_edit_session_fixture.dart';

void main() {
  late EditSessionFixture fx;

  setUp(() async => fx = await EditSessionFixture.create());

  test('saves edits', () async {
    fx.session.edit('# a\nmine');
    await fx.session.flush();

    expect(fx.onDisk(), '# a\nmine');
    expect(fx.session.state, EditState.saved);
  });

  test(
    'writes nothing if the edits reach the file during the backup',
    () async {
      final held = heldTempStore();
      final slow = fx.sessionBackingUpTo(held);
      slow.edit('# a\nsame');
      final saving = slow.flush();
      await held.reached.future;

      final theirs = await fx.editElsewhere('# a\nsame');
      slow.rescanNow(theirs);
      held.release.complete();
      await saving;

      expect(slow.state, EditState.saved);
      expect(slow.note.version, theirs.version);
      expect(fx.file().statSync().modified, theirs.modified);
    },
  );

  test('backs up the file once, before the first save', () async {
    fx.session.edit('# a\nfirst');
    await fx.session.flush();
    fx.session.edit('# a\nsecond');
    await fx.session.flush();

    expect(fx.onDisk(), '# a\nsecond');
    expect(fx.backedUp(), ['edit: # a\n']);
  });

  test('backs up a version from elsewhere before saving over it', () async {
    fx.session.edit('# a\nfirst');
    await fx.session.flush();
    fx.session.rescanNow(await fx.editElsewhere('# a\ntheirs'));
    expect(fx.session.text, '# a\ntheirs');
    fx.clearBackups();

    fx.session.edit('# a\nmine');
    await fx.session.flush();

    expect(fx.onDisk(), '# a\nmine');
    expect(fx.backedUp(), ['edit: # a\ntheirs']);
  });

  test('backs up nothing if nothing is saved', () async {
    fx.session.edit('# a\n');
    await fx.session.flush();

    expect(fx.backedUp(), isEmpty);
  });

  test('saves even if no backup can be made', () async {
    fx.blockBackups();
    addTearDown(fx.unblockBackups);

    fx.session.edit('# a\nmine');
    await fx.session.flush();

    expect(fx.onDisk(), '# a\nmine');
    expect(fx.session.state, EditState.saved);
  });

  test('takes changes from elsewhere while nothing is unsaved', () async {
    final theirs = await fx.editElsewhere('# a\ntheirs');

    final replaced = fx.session.rescanNow(theirs);

    expect(replaced, isTrue);
    expect(fx.session.text, '# a\ntheirs');
  });

  test('ignores scans that started before its last write', () async {
    final scannedAt = Moment.now();
    fx.session.edit('# a\nmine');
    await fx.session.flush();

    final replaced = fx.session.onRescan(fx.note, scannedAt: scannedAt);

    expect(replaced, isFalse);
    expect(fx.session.text, '# a\nmine');
  });

  test('ignores scans that started before the note was just written', () {
    final scannedAt = Moment.now();
    final created = NoteEditSession(
      fx.note,
      fx.files,
      tempDrafts(),
      writtenAt: Moment.now(),
    );
    addTearDown(created.dispose);

    // The scan may have listed the folder before the file was created.
    created.onRescan(null, scannedAt: scannedAt);

    expect(created.state, EditState.saved);
  });

  test('ignores scans that started during its last write', () async {
    fx.session.edit('# a\nmine');
    final saving = fx.session.flush();
    // Lets the save start its write, which then waits for the disk.
    await Future<void>.delayed(Duration.zero);
    final scannedAt = Moment.now();
    await saving;

    final replaced = fx.session.onRescan(fx.note, scannedAt: scannedAt);

    expect(replaced, isFalse);
    expect(fx.session.text, '# a\nmine');
  });

  test('a new version with the same text is not a change', () async {
    fx.session.edit('# a\nmine');
    await fx.session.flush();
    final restamped = await fx.restamp();

    fx.session.edit('# a\nmine, more');
    fx.session.rescanNow(restamped);
    await fx.session.flush();

    expect(fx.session.state, EditState.saved);
    expect(fx.onDisk(), '# a\nmine, more');
  });

  test('saves over a file that was only restamped', () async {
    fx.session.edit('# a\nmine');
    await fx.session.flush();
    await fx.restamp();

    fx.session.edit('# a\nmine, more');
    await fx.session.flush();

    expect(fx.session.state, EditState.saved);
    expect(fx.onDisk(), '# a\nmine, more');
  });
}
