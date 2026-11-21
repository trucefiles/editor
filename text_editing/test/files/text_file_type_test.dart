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

  test('a new document is written in its type\'s style', () async {
    final created = (await TextFiles(
      files(),
    ).create('New', type: _types.forNew, text: 'a:1\nb:2')).value;

    expect(textOf(created.path.value), 'a:1\r\nb:2');
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

  test("a text type's new kinds start with their text", () {
    expect(
      [for (final choice in _types.newFileChoices) choice.kind.startText],
      ['', 'name:'],
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
}

final class _OtherStart implements NewFileStart {
  const _OtherStart();
}
