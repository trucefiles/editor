import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart' show ArrivalBy;
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'support.dart';

void main() {
  final plugin = FakePlugin();
  late Map<FolderId, ImageFolder> folders;
  late MarkdownArrival arrival;

  Folder folder(String name) => Folder(
    id: folderId(name),
    name: name,
    color: 'teal',
    location: 'fake:$name',
  );

  ImageFolder images(String name) => folders[folderId(name)]!;

  setUp(() {
    folders = {
      for (final name in ['f1', 'f2'])
        folderId(name): ImageFolder(name, plugin: plugin),
    };
    arrival = MarkdownArrival((id) => folders[id]!.store);
    images('f1').putImage(nameA);
  });

  /// What [arrival] writes as [text], at [from] in f1, arrives in [to]'s
  /// [subfolder]; `null`: [text] as it is.
  Future<Result<String?, StoreError>> arrive(
    String text, {
    String from = 'doc.md',
    String to = 'f1',
    String? subfolder,
    ArrivalBy by = ArrivalBy.move,
  }) async => (await arrival.arrive((
    bytes: Uint8List.fromList(utf8.encode(text)),
    folder: folder('f1'),
    from: path(from),
    to: (
      folder: folder(to),
      subfolder: subfolder == null ? null : path(subfolder),
    ),
    by: by,
  ))).map((bytes) => bytes == null ? null : utf8.decode(bytes));

  test('at the same depth, no link changes', () async {
    final arrived = await arrive(
      '![](../document-images/$nameA)',
      from: 'a/doc.md',
      subfolder: 'b',
    );

    expect(arrived.value, isNull);
  });

  test('at another depth, the links of ours change, all else stays', () async {
    final arrived = await arrive(
      '# T\n\n![](document-images/$nameA) ![](pics/x.png)\n',
      subfolder: 'a/b',
    );

    expect(
      arrived.value,
      '# T\n\n![](../../document-images/$nameA) ![](pics/x.png)\n',
    );
  });

  test('a document linking none of ours never looks at the store', () async {
    final files = images('f1').files..failWith = StoreError.ioFailure;
    addTearDown(() => files.failWith = null);

    final arrived = await arrive('see ![](pics/x.png)', subfolder: 'a/b');

    expect(arrived.value, isNull);
  });

  test('in another folder, the images it links come along', () async {
    final arrived = await arrive('![](document-images/$nameA)', to: 'f2');

    expect(arrived.value, isNull);
    expect(images('f2').has(nameA), isTrue);
  });

  test('in another folder, an image in a table comes along', () async {
    final arrived = await arrive(
      '| a |\n|---|\n| ![](document-images/$nameA) |\n',
      to: 'f2',
    );

    expect(arrived.value, isNull);
    expect(images('f2').has(nameA), isTrue);
  });

  test('fails if its images can not come along', () async {
    final files = images('f2').files..failWith = StoreError.ioFailure;
    addTearDown(() => files.failWith = null);

    final arrived = await arrive('![](document-images/$nameA)', to: 'f2');

    expect(arrived.error, StoreError.ioFailure);
  });

  test('restored, its removed images come back first', () async {
    final store = images('f1').store;
    await store.remove((await store.images()).value[nameA]!);

    await arrive('![](document-images/$nameA)', by: ArrivalBy.restore);

    expect(images('f1').has(nameA), isTrue);
  });

  test('moved, removed images stay removed', () async {
    final store = images('f1').store;
    await store.remove((await store.images()).value[nameA]!);

    await arrive('![](document-images/$nameA)');

    expect(images('f1').has(nameA), isFalse);
  });
}
