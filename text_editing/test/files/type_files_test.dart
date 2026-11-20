import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../support/fake_text_merge.dart';

/// A made-up type that merges: files of `key:value` lines.
final class _KeyValueType extends TextFileType {
  const _KeyValueType();

  @override
  FakeFileType get support => const FakeFileType();

  @override
  String get name => 'Key value';

  /// Windows line breaks, as some formats want.
  @override
  TextFile get newFile => const TextFile.empty(lineBreak: '\r\n');

  @override
  List<NewFileKind> get newKinds => const [
    NewFileKind('Note'),
    NewFileKind('Named', start: TextStart('name:')),
  ];

  @override
  TextSummary<Object?> summary(String text, {required int maxLines}) =>
      _FirstLine(text);

  /// The values, not the keys.
  @override
  String textSearchWords(FileText read) =>
      [for (final line in read.text.split('\n')) line.split(':').last]
          .join('\n');

  @override
  FileCardSummary textCard(FileText read) => FileCardSummary(
    title: _FirstLine(read.text).firstLine,
    preview: (_) => '',
  );

  @override
  TextMerge get textMerge => const FakeTextMerge();
}

/// A text's first line, as its title.
final class _FirstLine implements TextSummary<Object?> {
  _FirstLine(String text) : firstLine = text.split('\n').first;

  @override
  final String firstLine;

  @override
  String get title => firstLine;

  @override
  String preview(Object? options) => '';
}

final _types = ShownFileTypes([const _KeyValueType()]);

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
      keptApart: (_) => false,
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
    FileMerge? merge = const TextBytesMerge(FakeTextMerge()),
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
      merge: const TextBytesMerge(FakeTextMerge()),
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
    final created = (await TextFiles(
      files(),
    ).create('New', type: _types.forNew, text: 'a:1\nb:2')).value;

    expect(textOf(created.path.value), 'a:1\r\nb:2');
  });

  test("search finds a document by its type's text", () async {
    put('a.md', 'colour:teal');
    final listedFiles = files();
    final file = (await listedFiles.read(path('a.md'))).value.listed;

    final [searchable] = searchablesOf(
      [file],
      filesOf: (_) => listedFiles,
      types: _types,
    );

    expect((await searchable.read())!.text, 'teal');
  });

  test("a text type's card and search read the file as text, titled by "
      'its summary', () async {
    put('a.md', 'title\ncolour:teal');
    final read = (await files().read(path('a.md'))).value;

    expect(_types.forNew.cardSummary(read)?.title, 'title');
    expect(_types.forNew.searchText(read), (
      title: 'title',
      text: 'title\nteal',
    ));
  });

  test('a text type shows and searches nothing of a file that is no text, '
      'and merges no such file', () async {
    put('a.md', '\u00ff\u00fe');
    final read = (await files().read(path('a.md'))).value;

    expect(_types.forNew.cardSummary(read), isNull);
    expect(_types.forNew.searchText(read), isNull);
    expect(_types.forNew.merge!.merge(read.bytes, utf8.encode('a:1')), isNull);
  });

  test("each type's new kinds are offered, the plain new document first", () {
    expect(_types.forNew, const _KeyValueType());
    expect(
      [
        for (final choice in _types.newFileChoices)
          (choice.label, choice.kind.startText, choice.type),
      ],
      [
        ('Note', '', const _KeyValueType()),
        ('Named', 'name:', const _KeyValueType()),
      ],
    );
  });

  test('a start that is no text is a bug, not an empty file', () {
    expect(
      () => const NewFileKind('Odd', start: _OtherStart()).startText,
      throwsStateError,
    );
  });

  test(
    "a gone document's conflict copy is written in its type's style",
    () async {
      expect(
        await TextFiles(files()).saveAsConflictOfGone(
          path('gone.md'),
          'a\nb',
          style: _types.forNew.newFile,
        ),
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
}

final class _OtherStart implements NewFileStart {
  const _OtherStart();
}
