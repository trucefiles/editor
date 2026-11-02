import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder/add_folder_flow.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final plugin = FakePlugin();
  late List<List<NamedCandidate>> added;
  late Result<List<Folder>, FolderError> answer;

  setUp(() {
    added = [];
    answer = const Ok([]);
  });

  AddFolderFlow flow({List<String> used = const []}) {
    final flow = AddFolderFlow(
      colors: const ['teal', 'pink', 'blue'],
      usedColors: used,
      add: (by, candidates) async {
        expect(by, same(plugin));
        added.add(candidates);
        return answer;
      },
    );
    addTearDown(flow.dispose);
    return flow;
  }

  NamingFolder naming(AddFolderFlow flow) => flow.step as NamingFolder;

  test('starts at the plugins, and stays there when a page gives none', () {
    final adding = flow()..took(plugin, const []);

    expect(adding.step, isA<ChoosingPlugin>());
  });

  test('names each folder after its directory, in colors not used yet', () {
    final adding = flow(used: ['teal'])
      ..took(plugin, [
        FakePlugin.candidate('notes'),
        FakePlugin.candidate('work'),
      ]);

    expect(naming(adding).name, 'notes');
    expect(naming(adding).color, 'pink');
    expect(naming(adding).location, 'fake:notes');
    expect(naming(adding).isLast, isFalse);
    adding.next();
    expect(naming(adding).name, 'work');
    expect(naming(adding).color, 'blue');
    expect(naming(adding).isLast, isTrue);
  });

  test('adds every folder together, as the user named them', () async {
    answer = Ok([
      Folder(
        id: folderId('notes'),
        name: 'Notes',
        color: 'pink',
        location: 'fake:notes',
      ),
    ]);
    final adding = flow()
      ..took(plugin, [
        FakePlugin.candidate('notes'),
        FakePlugin.candidate('work'),
      ])
      ..rename('Notes')
      ..recolor('blue')
      ..next()
      ..rename('Job');

    final result = await adding.finish();

    expect(result, isA<Ok<List<Folder>, FolderError>>());
    expect(
      [for (final named in added.single) (named.name, named.color)],
      [('Notes', 'blue'), ('Job', 'pink')],
    );
  });

  test('back goes to the folder before, then to the plugins, then ends', () {
    final adding = flow()
      ..took(plugin, [
        FakePlugin.candidate('notes'),
        FakePlugin.candidate('work'),
      ])
      ..next();

    expect(adding.back(), isTrue);
    expect(naming(adding).index, 0);
    expect(adding.back(), isTrue);
    expect(adding.step, isA<ChoosingPlugin>());
    expect(adding.back(), isFalse);
  });

  test('a failed add is the answer, and the names stay', () async {
    answer = const Err(FolderError.notSaved);
    final adding = flow()
      ..took(plugin, [FakePlugin.candidate('notes')])
      ..rename('Notes');

    expect(
      await adding.finish(),
      const Err<List<Folder>, FolderError>(FolderError.notSaved),
    );
    expect(naming(adding).name, 'Notes');
  });
}
