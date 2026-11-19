import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'support.dart';

void main() {
  late ImageFolder folder;

  setUp(() => folder = ImageFolder('f1'));

  group('add', () {
    test('keeps the image and gives the link from the document', () async {
      final link = await folder.store.add(
        bytesOf('png'),
        extension: 'png',
        documentFolder: path('notes'),
      );

      final name = ImageNames.nameIn(link.value)!;
      expect(link.value, '../document-images/$name');
      expect(folder.files.textOf('document-images/$name'), 'png');
    });

    test('fails where the folder can not be written', () async {
      folder.files.failWith = StoreError.ioFailure;

      final link = await folder.store.add(
        bytesOf('png'),
        extension: 'png',
        documentFolder: null,
      );

      expect(link.error, StoreError.ioFailure);
    });
  });

  group('kept apart', () {
    test(
      'images never show among the files, nor are told as written',
      () async {
        folder.files.put('a.md', 'text');
        await folder.store.add(
          bytesOf('x'),
          extension: 'png',
          documentFolder: null,
        );

        final listed = await folder.services.store.list();

        expect(listed.value.files.map((f) => f.path), [path('a.md')]);
        expect(folder.wrote, isEmpty);
      },
    );

    test('the document files can not write into the store', () async {
      final written = await folder.services.store.create(
        ImageNames.pathOf(nameA),
        bytesOf('x'),
      );

      expect(written, isA<Err<FileEntry, StoreError>>());
    });
  });

  test('images lists only names of ours in the store folder', () async {
    folder.putImage(nameA);
    folder.files.put('document-images/photo.png', 'other');
    folder.files.put('document-images/sub/$nameB', 'deeper');

    final images = await folder.store.images();

    expect(images.value.keys, [nameA]);
  });

  group('relink', () {
    test('changes only links to images in the store', () async {
      folder.putImage(nameA);

      final relink = (await folder.store.relinkFrom(path('a'))).value;

      expect(relink('document-images/$nameA'), '../document-images/$nameA');
      expect(relink('document-images/$nameB'), isNull);
      expect(relink('pics/photo.png'), isNull);
    });

    test('keeps a link that already works', () async {
      folder.putImage(nameA);

      final relink = (await folder.store.relinkFrom(null)).value;

      expect(relink('document-images/$nameA'), isNull);
    });
  });

  group('copy into another folder', () {
    test('copies the images there, keeping their names', () async {
      final other = ImageFolder('f2');
      folder.putImage(nameA);

      final copied = await folder.store.copyInto(other.store, {nameA, nameB});

      expect(copied, isA<Ok<void, StoreError>>());
      expect(other.files.textOf('document-images/$nameA'), 'image $nameA');
      expect(other.has(nameB), isFalse);
    });

    test('leaves an image already there', () async {
      final other = ImageFolder('f2');
      folder.putImage(nameA);
      other.files.put('document-images/$nameA', 'theirs');

      await folder.store.copyInto(other.store, {nameA});

      expect(other.files.textOf('document-images/$nameA'), 'theirs');
    });

    test('fails where the target can not be written', () async {
      final other = ImageFolder('f2');
      folder.putImage(nameA);
      other.files.failWith = StoreError.ioFailure;

      final copied = await folder.store.copyInto(other.store, {nameA});

      expect(copied.error, StoreError.ioFailure);
    });
  });

  group('remove and bring back', () {
    test('removes after a backup, then brings it back from it', () async {
      folder.putImage(nameA);
      final image = (await folder.store.images()).value[nameA]!;

      expect(await folder.store.remove(image), isA<Ok<void, StoreError>>());
      expect(folder.has(nameA), isFalse);

      await folder.store.bringBack({nameA, nameB});

      expect(folder.files.textOf('document-images/$nameA'), 'image $nameA');
      expect(folder.has(nameB), isFalse);
    });

    test('brings each missing image back from its latest backup', () async {
      Future<void> removeNow(String name) async =>
          folder.store.remove((await folder.store.images()).value[name]!);
      folder.putImage(nameA);
      await removeNow(nameA);
      folder.files.put('document-images/$nameA', 'newer');
      await removeNow(nameA);
      folder.putImage(nameB);
      await removeNow(nameB);

      await folder.store.bringBack({nameA, nameB});

      expect(folder.files.textOf('document-images/$nameA'), 'newer');
      expect(folder.files.textOf('document-images/$nameB'), 'image $nameB');
    });

    test('keeps an image changed since it was listed', () async {
      folder.putImage(nameA);
      final image = (await folder.store.images()).value[nameA]!;
      folder.putImage(nameA);

      final removed = await folder.store.remove(image);

      expect(removed.error, StoreError.changedSinceRead);
      expect(folder.has(nameA), isTrue);
    });

    test('never writes over an image that is there', () async {
      folder.putImage(nameA);
      final image = (await folder.store.images()).value[nameA]!;
      await folder.store.remove(image);
      folder.files.put('document-images/$nameA', 'new');

      await folder.store.bringBack({nameA});

      expect(folder.files.textOf('document-images/$nameA'), 'new');
    });
  });
}
