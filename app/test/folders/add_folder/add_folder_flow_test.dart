import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import '../../support.dart' show hostSyncthing;

void main() {
  final synced = Uri.parse('fake://host/synced');
  final plain = Uri.parse('fake://host/plain');
  late FakeSyncTool syncthing;
  late FakeSyncTool other;
  late FakeSyncTool plainFolder;
  late List<
    ({
      Uri address,
      String toolId,
      Selection selection,
      String name,
      String color,
    })
  >
  added;

  late Map<BaseFolder, SubfolderNames> keptNames;

  setUp(() {
    keptNames = {};
    syncthing = FakeSyncTool('syncthing', recognizes: {synced});
    other = FakeSyncTool('other');
    plainFolder = FakeSyncTool('plain');
    syncthing.place(synced).files
      ..emptyFolders.add(path('notes/work'))
      ..emptyFolders.add(path('home'));
    added = [];
  });

  /// A folder showing [selection] of the base folder at [address], synced
  /// by `syncthing`.
  DocumentFolder folderOn(
    Uri address, {
    Selection selection = const WholeFolder(),
  }) => DocumentFolder(
    id: 'f1',
    base: BaseFolder(id: 'b1', address: address, toolId: syncthing.id),
    selection: selection,
    name: 'Documents',
    color: 'teal',
  );

  AddFolderFlow flow([
    List<DocumentFolder> folders = const [],
    List<SyncTool>? tools,
  ]) {
    final flow = AddFolderFlow(
      AddFolderWork(
        tools: tools ?? [other, syncthing, plainFolder],
        colors: const ['teal', 'pink', 'green'],
        subfoldersOf: (base) => keptNames[base]!,
        add:
            ({
              required address,
              required toolId,
              required selection,
              required name,
              required color,
            }) async {
              added.add((
                address: address,
                toolId: toolId,
                selection: selection,
                name: name,
                color: color,
              ));
              return const Err(FolderError.overlaps);
            },
      ),
      folders,
    );
    addTearDown(flow.dispose);
    return flow;
  }

  test('tells each change of the step and the color', () async {
    final adding = flow();
    final steps = <AddFolderStep>[];
    adding.changes.listen((_) => steps.add(adding.step));

    await adding.pickBase(synced);
    adding.recolor('pink');

    expect(steps, [AddFolderStep.parts, AddFolderStep.parts]);
  });

  test('a folder a tool recognizes goes on to its parts', () async {
    final adding = flow();

    await adding.pickBase(synced);

    expect(adding.step, AddFolderStep.parts);
    expect(adding.tool, syncthing);
  });

  test('a folder on no disk is asked of a disk tool too', () async {
    final adding = flow(const [], [hostSyncthing(), syncthing]);

    await adding.pickBase(synced);

    expect(adding.tool, syncthing);
  });

  test('the user says which tool syncs a folder none recognizes', () async {
    final adding = flow();

    await adding.pickBase(plain);
    expect(adding.step, AddFolderStep.tool);
    adding.chooseTool(plainFolder);

    expect(adding.step, AddFolderStep.parts);
    expect(adding.tool, plainFolder);
  });

  test('a base folder added before keeps its tool, and what its folders '
      'show stays taken', () async {
    final before = folderOn(plain, selection: Selection.of([path('home')]));
    final kept = FakePlace()..files.emptyFolders.add(path('kept'));
    keptNames[before.base] = kept.subfolders;
    final adding = flow([before]);

    await adding.pickBase(plain);

    expect(adding.bases, [before.base]);
    expect(adding.tool, syncthing);
    expect(adding.parts.isTaken(path('home')), isTrue);
    expect(adding.parts.wholeTaken, isTrue);
    // Its folder names come from the place the app keeps for it.
    expect((await adding.parts.foldersIn(null)).value, [path('kept')]);
  });

  test('is named after the one subfolder picked, in a color no folder '
      'has yet', () async {
    final adding = flow([folderOn(plain)]);
    await adding.pickBase(synced);
    adding.parts.toggle(path('notes/work'));

    adding.toName();

    expect(adding.step, AddFolderStep.name);
    expect(adding.name, 'work');
    expect(adding.color, 'pink');
  });

  test('is named after the base folder when it shows more', () async {
    final adding = flow();
    await adding.pickBase(synced);
    adding.parts.chooseWhole(whole: true);

    adding.toName();

    expect(adding.name, 'synced');
  });

  test('adds the folder as chosen, and passes on a refusal', () async {
    final adding = flow();
    await adding.pickBase(synced);
    adding.parts
      ..toggle(path('home'))
      ..toggle(path('notes/work'));
    adding
      ..toName()
      ..rename('  Mine ')
      ..recolor('green');

    final result = await adding.finish();

    expect(result.error, FolderError.overlaps);
    expect(added.single, (
      address: synced,
      toolId: 'syncthing',
      selection: Selection.of([path('home'), path('notes/work')]),
      name: 'Mine',
      color: 'green',
    ));
  });

  test('back goes one step back, and ends before the first', () async {
    final adding = flow();
    await adding.pickBase(synced);
    adding.parts.chooseWhole(whole: true);
    adding.toName();

    expect(adding.back(), isTrue);
    expect(adding.step, AddFolderStep.parts);
    expect(adding.back(), isTrue);
    expect(adding.step, AddFolderStep.base);
    expect(adding.back(), isFalse);
  });
}
