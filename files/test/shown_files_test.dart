import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'support/fake_shown_type.dart';

final _types = ShownFileTypes([const FakeShownType()]);

const _copyName = 'a.fake-copy-20261101-120000.md';

void main() {
  late Folder folder;
  late FakeFolder raw;
  late FolderServices services;

  setUp(() {
    final plugin = FakePlugin();
    folder = Folder(
      id: folderId('f1'),
      name: 'Files',
      color: 'teal',
      location: 'fake:f1',
    );
    raw = plugin.folder(folder.id.folder);
    services = folderServices(
      raw,
      reach: folderReach(raw.files),
      bounds: FileBounds(handles: _types.handles, keptApart: (_) => false),
      checkEvery: () => const Duration(seconds: 1),
      backupsPath: tempFolder().path,
      deviceId: '0123456789abcdef',
      wrote: (_) {},
    );
  });

  void put(String name, String text) => raw.files.put(name, text);
  String? textOf(String name) => raw.files.textOf(name);

  /// The files of the folder.
  FilesOfFolder files() => FilesOfFolder(folder, services, _types);

  /// The conflict of `a.md`, as the scanner finds it now.
  Future<Conflict> conflict() async =>
      (await services.scanner.scan()).value.conflicts.single;

  /// The texts of the backups of [name].
  Future<List<String>> backupsOf(String name) async => [
    for (final backup in (await services.backups.listOf(path(name))).value)
      String.fromCharCodes((await services.backups.read(backup)).value),
  ];

  Future<ConflictSides> sides({
    FileMerge? merge = const FakeFileMerge(),
  }) async => (await ConflictSides.load(
    services,
    await conflict(),
    merge: merge,
  )).value;

  test('keeping both merged writes them once and backs up both', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'b:1\n');
    final found = await conflict();
    final shown = (await ConflictSides.load(
      services,
      found,
      merge: const FakeFileMerge(),
    )).value;

    final kept = await services.conflicts.resolve(
      found,
      shown.copy,
      KeepMerged(shown.merged!.bytes),
    );

    expect(kept, isA<Ok<void, ResolveError>>());
    expect(textOf('a.md'), 'a:1\nb:1\n');
    expect(textOf(_copyName), isNull);
    expect(await backupsOf('a.md'), containsAll(['a:1\n', 'b:1\n']));
  });
  test('nothing merged where the type does not merge', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'b:1\n');

    expect((await sides(merge: null)).merged, isNull);
  });
  test('nothing merged where the two cannot merge', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'not a unit\n');

    expect((await sides()).merged, isNull);
  });
  test('nothing merged when the main file is gone', () async {
    put(_copyName, 'b:1\n');

    final shown = await sides();

    expect(shown.current, isNull);
    expect(shown.merged, isNull);
  });
  test('search finds a file by the words its type gives', () async {
    put('a.md', 'colour:teal');
    final listedFiles = files();
    final file = (await listedFiles.read(path('a.md'))).value.listed;

    final [searchable] = searchablesOf(
      [file],
      filesOf: (_) => listedFiles,
      types: _types,
    );

    expect((await searchable.read!())!.text, 'teal');
  });
  test('documents are read again only once they change', () async {
    put('a.md', 'k:1');
    put('b.md', 'not kept');
    final reads = <String>[];
    final kept = FileReads<String>(
      FileAccess((_) => services, _types),
      readAs: (read) {
        reads.add(read.path.value);
        final text = String.fromCharCodes(read.bytes);
        return text.startsWith('k:') ? text : null;
      },
    );
    Future<ListedFile> listedOf(String name) async =>
        (await files().read(path(name))).value.listed;

    Future<List<ListedFile>> listedNow() async => [
      await listedOf('a.md'),
      await listedOf('b.md'),
    ];

    final first = await kept.readAll(await listedNow());
    expect([for (final text in first.values) text], ['k:1']);
    await kept.readAll(await listedNow());
    expect(reads, ['a.md', 'b.md'], reason: 'nothing changed');

    put('a.md', 'k:22');
    final changed = await kept.readAll(await listedNow());
    expect([for (final text in changed.values) text], ['k:22']);
    expect(reads, ['a.md', 'b.md', 'a.md']);
    expect(await kept.readAll(const []), isEmpty);
  });
  test('a document that could not be read is read again next time', () async {
    put('a.md', 'k:1');
    final kept = FileReads<String>(
      FileAccess((_) => services, _types),
      readAs: (read) => String.fromCharCodes(read.bytes),
    );
    final listed = [(await files().read(path('a.md'))).value.listed];

    raw.files.failWith = StoreError.ioFailure;
    expect(await kept.readAll(listed), isEmpty);
    raw.files.failWith = null;

    expect((await kept.readAll(listed)).values, ['k:1']);
  });

  test("each type's new kinds are offered, the plain new file first", () {
    expect(_types.forNew, const FakeShownType());
    expect(
      [for (final choice in _types.newFileChoices) choice.label],
      ['Note', 'List'],
    );
  });
}
