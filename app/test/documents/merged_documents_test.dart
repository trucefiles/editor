import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_plain_text/truce_plain_text.dart';
import 'package:truce_test_support/truce_test_support.dart' show FakeTextMerge;

import '../support.dart';

/// A made-up type that merges: `.kv` files of `key:value` lines.
final class _KeyValueSupport implements FileTypeSupport<PlainPreview> {
  const _KeyValueSupport();

  @override
  FileType get type => const FileType('key_value');

  @override
  Set<String> get extensions => const {'kv'};

  @override
  PlainSummary summary(String text, {required int maxLines}) =>
      PlainSummary(text, maxLines: maxLines);
}

final class _KeyValueType implements DocumentType {
  const _KeyValueType();

  @override
  _KeyValueSupport get support => const _KeyValueSupport();

  @override
  String get newFileExtension => '.kv';

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

const _copyName = 'a.sync-conflict-20261101-120000-ABCDEFG.kv';

void main() {
  late Directory dir;
  late DocumentFolder folder;
  late BaseFolderServices services;
  late String backups;

  setUp(() {
    dir = tempFolder();
    backups = tempFolder().path;
    folder = folderAt(dir);
    final tool = hostSyncthing();
    final place = tool.place(folder.base.address);
    services = baseFolderServices(
      place,
      syncToolName: tool.name,
      reach: folderReach(place.files),
      selection: folder.selection,
      handles: _types.handles,
      checkEvery: () => const Duration(seconds: 1),
      backupsPath: backups,
      deviceId: '0123456789abcdef',
      wrote: (_) {},
    );
  });

  File file(String name) => File('${dir.path}/$name');

  /// The conflicts of the folder as its scanner finds them now.
  Future<List<Conflict>> conflicts() async =>
      (await services.scanner.scan()).value.conflicts;

  /// The files of the folder, read with its copies as scanned now.
  Future<DocumentFiles> files() async {
    final found = await conflicts();
    return DocumentFiles(
      folder,
      services,
      _types,
      copiesOf: (key) => [
        for (final conflict in found)
          if (conflict.mainPath == key.path) ...conflict.copies,
      ],
    );
  }

  test('a document is read merged with its conflict copies', () async {
    file('a.kv').writeAsStringSync('a:1\nb:1\n');
    file(_copyName).writeAsStringSync('a:2\nc:1\n');

    final read = (await (await files()).open(path('a.kv'))).value;

    expect(read.text, 'a:2\nb:1\nc:1\n');
    expect(read.file.text, 'a:1\nb:1\n', reason: "the file's own text");
    expect(read.copies.single.merged, isTrue);
  });

  test('a new copy makes a new version, equal to the one listed', () async {
    file('a.kv').writeAsStringSync('a:1\n');
    final alone = (await (await files()).open(path('a.kv'))).value;
    file(_copyName).writeAsStringSync('a:2\n');
    final copies = (await conflicts()).single.copies;
    final merged = (await (await files()).open(path('a.kv'))).value;

    expect(DocumentVersion(merged), isNot(DocumentVersion(alone)));
    expect(
      DocumentVersion(merged),
      listedVersion(merged.document, copies: copies),
    );
    expect(DocumentVersion(alone), listedVersion(alone.document));
  });

  test('writing over a merged version settles its copies', () async {
    file('a.kv').writeAsStringSync('a:1\n');
    file(_copyName).writeAsStringSync('a:2\n');
    final documents = await files();
    final read = (await documents.open(path('a.kv'))).value;

    final written = (await documents.save(read, 'a:2\nb:1\n')).value;

    expect(file('a.kv').readAsStringSync(), 'a:2\nb:1\n');
    expect(file(_copyName).existsSync(), isFalse);
    expect(written.copies, isEmpty);
    final saved = [
      for (final backup in (await services.backups.listOf(path('a.kv'))).value)
        String.fromCharCodes((await services.backups.read(backup)).value),
    ];
    expect(saved, containsAll(['a:1\n', 'a:2\n']), reason: 'all inputs');
  });

  test('a failed write keeps the copies', () async {
    file('a.kv').writeAsStringSync('a:1\n');
    file(_copyName).writeAsStringSync('a:2\n');
    final documents = await files();
    final read = (await documents.open(path('a.kv'))).value;
    file('a.kv').writeAsStringSync('a:3\n');

    final written = await documents.save(read, 'a:2\nb:1\n');

    expect(written, isA<Err<DocumentText, StoreError>>());
    expect(file(_copyName).existsSync(), isTrue);
  });

  test('settling writes the merged text once, only with copies', () async {
    file('a.kv').writeAsStringSync('a:1\n');
    final documents = await files();
    final alone = (await documents.open(path('a.kv'))).value;
    expect(identical((await documents.settled(alone)).value, alone), isTrue);

    file(_copyName).writeAsStringSync('b:1\n');
    final merged = (await (await files()).open(path('a.kv'))).value;
    final settled = (await (await files()).settled(merged)).value;
    expect(file('a.kv').readAsStringSync(), 'a:1\nb:1\n');
    expect(settled.copies, isEmpty);
  });

  test('the folder contents give the copies to the document, not as '
      'conflicts, unless the file is gone', () async {
    file('a.kv').writeAsStringSync('a:1\n');
    file(_copyName).writeAsStringSync('a:2\n');
    file('gone.sync-conflict-20261101-120000-ABCDEFG.kv')
        .writeAsStringSync('a:1\n');
    final scan = (await services.scanner.scan()).value;
    final contents = FolderContents(
      FolderState({
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
      }),
      folders: [folder],
      types: _types,
    );
    final key = (baseId: folder.base.id, path: path('a.kv'));

    expect(contents.copiesOf(key), hasLength(1));
    expect(contents.conflicts.forDocument(key), isNull);
    expect(contents.conflicts.orphans.single.key.path, path('gone.kv'));
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
    /// The document steps, reading with the copies as scanned now.
    Future<DocumentSteps> steps() async {
      final found = await conflicts();
      return DocumentSteps(
        DocumentsWork(
          files: FolderFiles(
            (_) => services,
            _types,
            copiesOf: (key) => [
              for (final conflict in found)
                if (conflict.mainPath == key.path) ...conflict.copies,
            ],
          ),
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
      file('a.kv').writeAsStringSync('a:1\n');
      file(_copyName).writeAsStringSync('b:1\n');
    });

    test('a move takes the copies along, merged into the file', () async {
      final read = (await (await files()).open(path('a.kv'))).value;

      final moved = (await (await steps()).move(read, (
        folder: folder,
        subfolder: null,
      ), title: 'b')).value;

      expect(moved.path, path('b.kv'));
      expect(file('b.kv').readAsStringSync(), 'a:1\nb:1\n');
      expect(file(_copyName).existsSync(), isFalse);
    });

    test('a delete leaves no copy behind', () async {
      final read = (await (await files()).open(path('a.kv'))).value;

      await (await steps()).delete(read, read.text);

      expect(file('a.kv').existsSync(), isFalse);
      expect(file(_copyName).existsSync(), isFalse);
    });
  });
}
