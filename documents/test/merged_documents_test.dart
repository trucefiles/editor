import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// A made-up type that merges: files of `key:value` lines.
final class _KeyValueType implements DocumentType {
  const _KeyValueType();

  @override
  FakeFileType get support => const FakeFileType();

  @override
  String get newFileExtension => '.md';

  @override
  DocumentCardSummary cardSummary(DocumentText read) =>
      DocumentCardSummary(title: read.summary.firstLine, preview: (_) => '');

  @override
  TextMerge get merge => const FakeTextMerge();
}

/// Keeps no settings.
final class _NoSettings implements DocumentSettingsKeeper {
  @override
  DocumentSettings settingsOf(DocumentKey document) =>
      DocumentSettings.defaults;

  @override
  Future<void> edit(
    DocumentKey document,
    DocumentSettings Function(DocumentSettings settings) change,
  ) async {}

  @override
  Future<void> forget(DocumentKey document) async {}
}

final _types = DocumentTypes([
  const _KeyValueType(),
], forNew: const _KeyValueType());

const _copyName = 'a.fake-copy-20261101-120000.md';

void main() {
  late DocumentFolder folder;
  late FakePlace place;
  late BaseFolderServices services;

  setUp(() {
    final tool = FakeSyncTool('fake');
    folder = DocumentFolder(
      id: 'f1',
      base: BaseFolder(
        id: 'b1',
        address: Uri.parse('fake:/f1'),
        toolId: tool.id,
      ),
      selection: const WholeFolder(),
      name: 'Documents',
      color: 'teal',
    );
    place = tool.place(folder.base.address);
    services = baseFolderServices(
      place,
      syncToolName: tool.name,
      reach: folderReach(place.files),
      selection: folder.selection,
      handles: _types.handles,
      checkEvery: () => const Duration(seconds: 1),
      backupsPath: tempFolder().path,
      deviceId: '0123456789abcdef',
      wrote: (_) {},
    );
  });

  void put(String name, String text) => place.files.put(name, text);
  String? textOf(String name) => place.files.textOf(name);

  /// The folder state, as its scanner finds the folder now.
  Future<FolderState> listed() async {
    final scan = (await services.scanner.scan()).value;
    return FolderState({
      folder.base.id: Listed(
        files: {for (final entry in scan.files) entry.path: entry},
        conflicts: {
          for (final conflict in scan.conflicts) conflict.mainPath: conflict,
        },
        subfolders: const {},
        unreadable: const [],
        marks: MarksFiles.none,
        listedAt: Moment.now(),
      ),
    });
  }

  /// The copies of each document, as the folder state holds them now.
  Future<CopiesOf> copiesNow() async {
    final state = await listed();
    return (DocumentKey key) => mergedCopiesOf(state, _types, key);
  }

  DocumentKey keyOf(String name) => (baseId: folder.base.id, path: path(name));

  /// The texts of the backups of [name].
  Future<List<String>> backupsOf(String name) async => [
    for (final backup in (await services.backups.listOf(path(name))).value)
      String.fromCharCodes((await services.backups.read(backup)).value),
  ];

  /// The files of the folder, read with its copies as listed now.
  Future<DocumentFiles> files() async =>
      DocumentFiles(folder, services, _types, copiesOf: await copiesNow());

  test('a document is read merged with its conflict copies', () async {
    put('a.md', 'a:1\nb:1\n');
    put(_copyName, 'a:2\nc:1\n');

    final read = (await (await files()).open(path('a.md'))).value;

    expect(read.text, 'a:2\nb:1\nc:1\n');
    expect(read.file.text, 'a:1\nb:1\n', reason: "the file's own text");
    expect(read.copies.single.merged, isTrue);
  });

  test('a new copy makes a new version, equal to the one listed', () async {
    put('a.md', 'a:1\n');
    final alone = (await (await files()).open(path('a.md'))).value;
    put(_copyName, 'a:2\n');
    final copies = (await copiesNow())(keyOf('a.md'));
    final merged = (await (await files()).open(path('a.md'))).value;

    expect(DocumentVersion(merged), isNot(DocumentVersion(alone)));
    expect(
      DocumentVersion(merged),
      listedVersion(merged.document, copies: copies),
    );
    expect(DocumentVersion(alone), listedVersion(alone.document));
  });

  test('writing over a merged version settles its copies', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'a:2\n');
    final documents = await files();
    final read = (await documents.open(path('a.md'))).value;

    final written = (await documents.save(read, 'a:2\nb:1\n')).value;

    expect(textOf('a.md'), 'a:2\nb:1\n');
    expect(textOf(_copyName), isNull);
    expect(written.copies, isEmpty);
    expect(
      await backupsOf('a.md'),
      containsAll(['a:1\n', 'a:2\n']),
      reason: 'all inputs',
    );
  });

  test(
    "the file's own text is backed up once, when asked or with copies",
    () async {
      put('a.md', 'a:1\n');
      final alone = (await (await files()).open(path('a.md'))).value;
      await (await files()).save(alone, 'a:2\n');
      expect(await backupsOf('a.md'), isEmpty, reason: 'not asked');

      final read = (await (await files()).open(path('a.md'))).value;
      await (await files()).save(read, 'a:3\n', backUpFirst: true);
      expect(await backupsOf('a.md'), ['a:2\n']);

      put(_copyName, 'b:1\n');
      final merged = (await (await files()).open(path('a.md'))).value;
      await (await files()).save(merged, 'a:4\n', backUpFirst: true);
      expect(
        (await backupsOf('a.md')).where((text) => text == 'a:3\n'),
        hasLength(1),
      );
    },
  );

  test('a failed write keeps the copies', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'a:2\n');
    final documents = await files();
    final read = (await documents.open(path('a.md'))).value;
    put('a.md', 'a:3\n');

    final written = await documents.save(read, 'a:2\nb:1\n');

    expect(written, isA<Err<DocumentText, StoreError>>());
    expect(textOf(_copyName), isNotNull);
  });

  test('settling writes the merged text once, only with copies', () async {
    put('a.md', 'a:1\n');
    final documents = await files();
    final alone = (await documents.open(path('a.md'))).value;
    expect(identical((await documents.settled(alone)).value, alone), isTrue);

    put(_copyName, 'b:1\n');
    final merged = (await (await files()).open(path('a.md'))).value;
    final settled = (await (await files()).settled(merged)).value;
    expect(textOf('a.md'), 'a:1\nb:1\n');
    expect(settled.copies, isEmpty);
  });

  test('the folder contents give the copies to the document, not as '
      'conflicts, unless the file is gone', () async {
    put('a.md', 'a:1\n');
    put(_copyName, 'a:2\n');
    put('gone.fake-copy-20261101-120000.md', 'a:1\n');
    final state = await listed();
    final contents = FolderContents(state, folders: [folder], types: _types);
    final key = keyOf('a.md');

    expect(contents.copiesOf(key), hasLength(1));
    expect(contents.conflicts.forDocument(key), isNull);
    expect(contents.conflicts.orphans.single.key.path, path('gone.md'));
    expect(conflictWaitsIn(state, _types, key), isFalse);
    expect(conflictWaitsIn(state, _types, keyOf('gone.md')), isTrue);
    final document = contents.findDocument(key)!;
    expect(
      contents.observe(key),
      isA<Found>().having(
        (found) => found.version,
        'version',
        listedVersion(document, copies: contents.copiesOf(key)),
      ),
    );
  });

  group('a move or delete of a document with copies', () {
    /// The document steps, reading with the copies as listed now.
    Future<DocumentSteps> steps() async {
      final copiesOf = await copiesNow();
      return DocumentSteps(
        DocumentsWork(
          files: FolderFiles((_) => services, _types, copiesOf: copiesOf),
          servicesOf: (_) => services,
          settings: _NoSettings(),
          conflictWaits: (_) => false,
          folders: () async => [folder],
          drafts: DraftsByBase((id) => '${tempFolder().path}/$id'),
          types: _types,
        ),
      );
    }

    setUp(() {
      put('a.md', 'a:1\n');
      put(_copyName, 'b:1\n');
    });

    test('a move takes the copies along, merged into the file', () async {
      final read = (await (await files()).open(path('a.md'))).value;

      final moved = (await (await steps()).move(read, (
        folder: folder,
        subfolder: null,
      ), title: 'b')).value;

      expect(moved.path, path('b.md'));
      expect(textOf('b.md'), 'a:1\nb:1\n');
      expect(textOf(_copyName), isNull);
    });

    test('a delete leaves no copy behind', () async {
      final read = (await (await files()).open(path('a.md'))).value;

      await (await steps()).delete(read, read.text);

      expect(textOf('a.md'), isNull);
      expect(textOf(_copyName), isNull);
    });
  });
}
