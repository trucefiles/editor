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
}
