import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../support.dart';
import 'file_fixture.dart';

void main() {
  late FileFixture fixture;

  setUp(() async => fixture = await FileFixture.create());

  const id = EffectId(1);

  test(
    'a write over a version changed since tells what the file holds',
    () async {
      final effects = fixture.effects(ExistingFile(fixture.file));
      await fixture.editElsewhere('two\n');

      final wrote = await effects.run(
        Write(id, 'x', over: fixture.file.seen, backUpFirst: false),
      );

      expect(
        wrote,
        isA<Wrote>().having(
          (wrote) => wrote.outcome,
          'outcome',
          isA<Changed>().having(
            (changed) => changed.theirs.text,
            'text',
            'two\n',
          ),
        ),
      );
      expect(fixture.onDisk('a.md'), 'two\n');
    },
  );

  test('a written file is told with its document', () async {
    final effects = fixture.effects(ExistingFile(fixture.file));

    final wrote = await effects.run(
      Write(id, 'x\n', over: fixture.file.seen, backUpFirst: true),
    );

    final outcome = (wrote! as Wrote<ReadVersion>).outcome;
    expect(fixture.onDisk('a.md'), 'x\n');
    final written = (outcome as Written<ReadVersion>).seen.version.read;
    expect((written.path, written.textFile.text), (path('a.md'), 'x\n'));
  });

  test('a draft goes to the file it names', () async {
    final effects = fixture.effects(ExistingFile(fixture.file));
    final copy = (await fixture.files[folderId('f2')]!.create(
      'b',
      type: appFileTypes().forNew,
      text: 'one\n',
    )).value;

    await effects.run(
      KeepDraft(id, base: 'one\n', text: 'x', file: copy.seen.version),
    );

    expect((await fixture.draftsIn('f2')).single.path, path('b.md'));
    expect(await fixture.draftsIn('f1'), isEmpty);
    await effects.run(DropDraft(file: copy.seen.version));
    expect(await fixture.draftsIn('f2'), isEmpty);
  });

  test('a restore where a file is now tells what it holds', () async {
    final effects = fixture.effects(ExistingFile(fixture.file));

    final wrote = await effects.run(
      Restore(id, 'x\n', where: fixture.file.seen),
    );

    expect(
      (wrote! as Wrote).outcome,
      isA<Taken>().having((taken) => taken.there.text, 'text', 'one\n'),
    );
  });

  test("a new document's draft goes where its file goes", () async {
    final effects = fixture.effects(fixture.newFile);

    expect(
      await effects.run(
        const KeepDraft(
          id,
          base: null,
          text: 'Milk',
          file: null,
          firstLine: 'Milk',
        ),
      ),
      isA<DraftKept>().having((kept) => kept.kept, 'kept', isTrue),
    );
    expect((await fixture.draftsIn('f1')).single.path, path('Milk.md'));

    effects.place(
      NewFile(
        (folder: fixture.folders[1], subfolder: null),
        type: appFileTypes().forNew,
        name: 'Eggs',
      ),
    );

    await eventually(() async => (await fixture.draftsIn('f2')).isNotEmpty);
    final moved = (await fixture.draftsIn('f2')).single;
    expect((moved.path, moved.text), (path('Eggs.md'), 'Milk'));
    expect(await fixture.draftsIn('f1'), isEmpty);
  });

  test("a new document's draft, recovered at the next start, goes into the "
      'new subfolder the user asked for', () async {
    final effects = fixture.effects(
      NewFile(
        (folder: fixture.folders[0], subfolder: path('2026')),
        type: appFileTypes().forNew,
        newSubfolder: true,
      ),
    );
    await effects.run(
      const KeepDraft(
        id,
        base: null,
        text: 'Milk',
        file: null,
        firstLine: 'Milk',
      ),
    );

    final recovery = DraftRecovery(
      fixture.drafts[folderId('f1')]!,
      files: fixture.files[folderId('f1')]!,
      types: appFileTypes(),
    );
    expect(await recovery.recover(before: fixture.later), 1);

    expect(fixture.onDisk('2026/Milk.md'), 'Milk');
    expect(fixture.onDisk('Milk.md'), isNull);
  });

  test("a new document's draft, named by the user, goes back to its first "
      'line once the name is cleared', () async {
    final effects = fixture.effects(
      NewFile(
        (folder: fixture.folders[0], subfolder: null),
        type: appFileTypes().forNew,
        name: 'Foo',
      ),
    );
    await effects.run(
      const KeepDraft(
        id,
        base: null,
        text: 'Milk',
        file: null,
        firstLine: 'Milk',
      ),
    );
    expect((await fixture.draftsIn('f1')).single.path, path('Foo.md'));

    effects.place(fixture.newFile);

    await eventually(
      () async =>
          (await fixture.draftsIn('f1')).singleOrNull?.path == path('Milk.md'),
    );
  });

  test('a dropped draft is not moved along', () async {
    final effects = fixture.effects(fixture.newFile);
    await effects.run(
      const KeepDraft(
        id,
        base: null,
        text: 'Milk',
        file: null,
        firstLine: 'Milk',
      ),
    );
    await effects.run(const DropDraft(file: null));

    effects.place(
      NewFile((
        folder: fixture.folders[1],
        subfolder: null,
      ), type: appFileTypes().forNew),
    );

    expect(await fixture.draftsIn('f1'), isEmpty);
    expect(await fixture.draftsIn('f2'), isEmpty);
  });

  test('a conflict copy goes next to the version named', () async {
    final effects = fixture.effects(fixture.newFile);

    final kept = await effects.run(
      KeepAsConflict(id, 'mine\n', nextTo: fixture.file.seen),
    );

    expect(kept, isA<ConflictKept>().having((kept) => kept.ok, 'ok', isTrue));
  });
}
