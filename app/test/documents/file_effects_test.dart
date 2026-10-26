import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document_file.dart';
import 'package:truce_editor/documents/note_version.dart';

import '../support.dart' hide noteOf;
import 'document_fixture.dart';

void main() {
  late DocumentFixture fixture;

  setUp(() async => fixture = await DocumentFixture.create());

  const id = EffectId(1);

  test(
    'a write over a version changed since tells what the file holds',
    () async {
      final effects = fixture.effects(ExistingFile(fixture.note));
      await fixture.editElsewhere('two\n');

      final wrote = await effects.run(
        Write(id, 'x', over: fixture.note.seen, backUpFirst: false),
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

  test('a written file is where the effects go on', () async {
    final effects = fixture.effects(ExistingFile(fixture.note));

    final wrote = await effects.run(
      Write(id, 'x\n', over: fixture.note.seen, backUpFirst: true),
    );

    expect((wrote! as Wrote).outcome, isA<Written>());
    expect(fixture.onDisk('a.md'), 'x\n');
    final file = effects.file as ExistingFile;
    expect(file.note.file.text, 'x\n');
  });

  test('a restore where a file is now tells what it holds', () async {
    final effects = fixture.effects(ExistingFile(fixture.note));

    final wrote = await effects.run(const Restore(id, 'x\n'));

    expect(
      (wrote! as Wrote).outcome,
      isA<Taken>().having((taken) => taken.there.text, 'text', 'one\n'),
    );
  });

  test("a new document's draft goes where its file goes", () async {
    final effects = fixture.effects(fixture.newFile);

    expect(
      await effects.run(const KeepDraft(id, base: null, text: 'Milk')),
      isA<DraftKept>().having((kept) => kept.kept, 'kept', isTrue),
    );
    expect((await fixture.draftsIn('f1')).single.path, path('Milk.md'));

    effects.place(
      NewFile((folder: fixture.folders[1], subfolder: null), name: 'Eggs'),
    );

    await eventually(() async => (await fixture.draftsIn('f2')).isNotEmpty);
    final moved = (await fixture.draftsIn('f2')).single;
    expect((moved.path, moved.text), (path('Eggs.md'), 'Milk'));
    expect(await fixture.draftsIn('f1'), isEmpty);
  });

  test('a dropped draft is not moved along', () async {
    final effects = fixture.effects(fixture.newFile);
    await effects.run(const KeepDraft(id, base: null, text: 'Milk'));
    await effects.run(const DropDraft());

    effects.place(NewFile((folder: fixture.folders[1], subfolder: null)));

    expect(await fixture.draftsIn('f1'), isEmpty);
    expect(await fixture.draftsIn('f2'), isEmpty);
  });
}
