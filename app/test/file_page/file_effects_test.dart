import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

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
      type: appNewTextType(),
      text: 'one\n',
    )).value;

    await effects.run(
      KeepDraft(
        id,
        base: copy.seen.version,
        text: 'x',
        file: copy.seen.version,
      ),
    );

    final [kept] = await fixture.draftsIn('f2');
    expect((kept.path, kept.text), (path('b.md'), 'x'));
    expect((kept.of as OwnDraft).part, copy.fingerprint);
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
        type: appNewTextType(),
        name: 'Eggs',
      ),
    );

    await eventually(() async => (await fixture.draftsIn('f2')).isNotEmpty);
    final moved = (await fixture.draftsIn('f2')).single;
    expect((moved.path, moved.text), (path('Eggs.md'), 'Milk'));
    expect(await fixture.draftsIn('f1'), isEmpty);
  });

  group("a new document's draft, placed in a folder that refuses it", () {
    late TextEditEffects effects;
    late FileDrafts second;

    /// Drafts in a place that is a file, so none can be kept there.
    FileDrafts refusing() => FileDrafts(
      Directory('${(File('${tempFolder().path}/file')..createSync()).path}/d'),
    );

    Future<void> keep(String text) => effects.run(
      KeepDraft(id, base: null, text: text, file: null, firstLine: text),
    );

    setUp(() async {
      effects = fixture.effects(fixture.newFile);
      await keep('Milk');
      second = fixture.drafts[folderId('f2')]!;
      fixture.drafts[folderId('f2')] = refusing();
      effects.place(
        NewFile((
          folder: fixture.folders[1],
          subfolder: null,
        ), type: appNewTextType()),
      );
      // The refused keep has run once the next one, queued after it, has.
      await keep('Milk');
      fixture.drafts[folderId('f2')] = second;
    });

    test('stays kept where it was', () async {
      expect((await fixture.draftsIn('f1')).single.path, path('Milk.md'));
    });

    test('kept there later, it is dropped where it was', () async {
      await keep('Milk and eggs');

      expect(await fixture.draftsIn('f1'), isEmpty);
      expect((await fixture.draftsIn('f2')).single.text, 'Milk and eggs');
    });

    test('dropped, no draft is left anywhere', () async {
      await effects.run(const DropDraft(file: null));

      expect(await fixture.draftsIn('f1'), isEmpty);
      expect(await fixture.draftsIn('f2'), isEmpty);
    });
  });

  test("a new document's draft, recovered at the next start, goes into the "
      'new subfolder the user asked for', () async {
    final effects = fixture.effects(
      NewFile(
        (folder: fixture.folders[0], subfolder: path('2026')),
        type: appNewTextType(),
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

    await recoverFolderDrafts(
      fixture.drafts[folderId('f1')]!,
      fixture.bytes[folderId('f1')]!,
      recoverOwn: recoverEdits,
      before: fixture.later,
    );

    expect(fixture.onDisk('2026/Milk.md'), 'Milk');
    expect(fixture.onDisk('Milk.md'), isNull);
  });

  test("a new document's draft, named by the user, goes back to its first "
      'line once the name is cleared', () async {
    final effects = fixture.effects(
      NewFile(
        (folder: fixture.folders[0], subfolder: null),
        type: appNewTextType(),
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
      ), type: appNewTextType()),
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
