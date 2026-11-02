import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// A made-up type that merges: files of `key:value` lines.
final class _KeyValueType implements ShownFileType {
  const _KeyValueType();

  @override
  FakeFileType get support => const FakeFileType();

  @override
  String get name => 'Key value';

  /// Windows line breaks, as some formats want.
  @override
  TextFile get newFile => const TextFile.empty(lineBreak: '\r\n');

  /// The values, not the keys.
  @override
  String searchText(FileText read) =>
      [for (final line in read.text.split('\n')) line.split(':').last]
          .join('\n');

  @override
  FileCardSummary cardSummary(FileText read) =>
      FileCardSummary(title: read.summary.firstLine, preview: (_) => '');

  @override
  TextMerge get merge => const FakeTextMerge();
}

final _types = ShownFileTypes(
  [const _KeyValueType()],
  newFileChoices: const [NewFileChoice('Note', _KeyValueType())],
);

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
      handles: _types.handles,
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
    TextMerge? merge = const FakeTextMerge(),
  }) async => (await ConflictSides.load(
    services,
    await conflict(),
    merge: merge,
  )).value;

  test('both merged, in the main file\'s byte style, with what lost', () async {
    put('a.md', 'a:1\r\nb:2\r\n');
    put(_copyName, 'a:2\nb:1\n');

    final merged = (await sides()).merged!;

    expect(String.fromCharCodes(merged.bytes), 'a:2\r\nb:2\r\n');
    expect(merged.lost, ['a', 'b'], reason: 'each side lost one');
  });

  test('keeping both merged writes them once and backs up both', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'b:1\n');
    final found = await conflict();
    final shown = (await ConflictSides.load(
      services,
      found,
      merge: const FakeTextMerge(),
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

  test('a new document is written in its type\'s style', () async {
    final created = (await files().create(
      'New',
      type: _types.forNew,
      text: 'a:1\nb:2',
    )).value;

    expect(textOf(created.path.value), 'a:1\r\nb:2');
  });

  test("search finds a document by its type's text", () async {
    put('a.md', 'colour:teal');
    final listedFiles = files();
    final file = (await listedFiles.open(path('a.md'))).value.listed;

    final [searchable] = searchablesOf(
      [file],
      filesOf: (_) => listedFiles,
      types: _types,
    );

    expect((await searchable.read())!.text, 'teal');
  });

  test('the plain new document is the first one offered', () {
    const named = NewFileChoice(
      'Named',
      _KeyValueType(),
      startNamed: _startNamed,
    );
    expect(_types.forNew, const _KeyValueType());
    expect((named.named, named.startText('Home')), (true, 'name:Home'));
    expect(
      (
        _types.newFileChoices.single.named,
        _types.newFileChoices.single.startText('x'),
      ),
      (false, ''),
    );
  });

  test(
    "a gone document's conflict copy is written in its type's style",
    () async {
      expect(
        await files().saveAsConflictOfGone(path('gone.md'), 'a\nb'),
        isA<Ok<void, StoreError>>(),
      );

      expect(
        [
          for (final MapEntry(:key, :value) in raw.files.files.entries)
            (key.value.startsWith('gone'), String.fromCharCodes(value.bytes)),
        ],
        [(true, 'a\r\nb')],
      );
    },
  );

  test('documents are read again only once they change', () async {
    put('a.md', 'k:1');
    put('b.md', 'not kept');
    final reads = <String>[];
    final kept = FileReads<String>(
      FileAccess((_) => services, _types),
      readAs: (read) {
        reads.add(read.path.value);
        return read.text.startsWith('k:') ? read.text : null;
      },
    );
    Future<ListedFile> listedOf(String name) async =>
        (await files().open(path(name))).value.listed;

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
      readAs: (read) => read.text,
    );
    final listed = [(await files().open(path('a.md'))).value.listed];

    raw.files.failWith = StoreError.ioFailure;
    expect(await kept.readAll(listed), isEmpty);
    raw.files.failWith = null;

    expect((await kept.readAll(listed)).values, ['k:1']);
  });
}

String _startNamed(String name) => 'name:$name';
