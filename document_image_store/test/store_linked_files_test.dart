import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'support.dart';

void main() {
  final plugin = FakePlugin();
  late Map<FolderId, ImageFolder> folders;
  late StoreLinkedFiles linked;

  Folder folder(String name) => Folder(
    id: folderId(name),
    name: name,
    color: 'teal',
    location: 'fake:$name',
  );

  setUp(() {
    folders = {
      for (final name in ['f1', 'f2'])
        folderId(name): ImageFolder(name, plugin: plugin),
    };
    linked = StoreLinkedFiles((folder) => folders[folder.id]!.store);
    folders[folderId('f1')]!.putImage(nameA);
  });

  test('a move at the same depth changes no link', () async {
    final relink = await linked.relinkFor(
      folder('f1'),
      from: path('a/doc.md'),
      toFolder: path('b'),
    );

    expect(relink.value, isNull);
  });

  test('a move to another depth changes the links of ours', () async {
    final relink = (await linked.relinkFor(
      folder('f1'),
      from: path('doc.md'),
      toFolder: path('a/b'),
    )).value!;

    expect(relink('document-images/$nameA'), '../../document-images/$nameA');
    expect(relink('pics/x.png'), isNull);
  });

  test('a move to another folder copies the images the text names', () async {
    await linked.copyFor(
      'see document-images/$nameA',
      from: folder('f1'),
      to: folder('f2'),
    );

    expect(folders[folderId('f2')]!.has(nameA), isTrue);
  });

  test('bringing back reads the names from the text', () async {
    final store = folders[folderId('f1')]!.store;
    await store.remove((await store.images()).value[nameA]!);

    await linked.bringBack('![](document-images/$nameA)', folder('f1'));

    expect(folders[folderId('f1')]!.has(nameA), isTrue);
  });
}
