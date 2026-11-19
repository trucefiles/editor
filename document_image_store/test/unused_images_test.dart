import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'support.dart';

void main() {
  late ImageFolder folder;
  late List<String>? drafts;

  setUp(() {
    folder = ImageFolder('f1');
    drafts = [];
  });

  /// The cleanup, two hours after the images were put.
  UnusedImages cleanup() => UnusedImages(
    folder.store,
    folder.services,
    drafts: () async => drafts,
    now: () =>
        DateTime.fromMillisecondsSinceEpoch(0).add(const Duration(hours: 2)),
  );

  List<String> names(List<FileEntry> images) => [
    for (final image in images) image.path.name,
  ];

  test('finds the images no document shows, and removes them', () async {
    folder.putImage(nameA);
    folder.putImage(nameB);
    folder.files.put('a.md', '![](document-images/$nameA)');

    final unused = (await cleanup().find()).value;
    expect(names(unused), [nameB]);

    expect(await cleanup().remove(unused), 1);
    expect(folder.has(nameA), isTrue);
    expect(folder.has(nameB), isFalse);
  });

  test('an image a conflict copy or a draft shows stays', () async {
    folder.putImage(nameA);
    folder.putImage(nameB);
    folder.files.put('a.md', 'no images');
    folder.files.put('a.fake-copy-20261101-120000.md', 'see $nameA');
    drafts = ['see $nameB'];

    expect((await cleanup().find()).value, isEmpty);
  });

  test('an image changed in the last hour stays', () async {
    folder.putImage(nameA);

    final fresh = UnusedImages(
      folder.store,
      folder.services,
      drafts: () async => drafts,
      now: () =>
          DateTime.fromMillisecondsSinceEpoch(0)
              .add(const Duration(minutes: 30)),
    );

    expect((await fresh.find()).value, isEmpty);
  });

  test('refuses if a draft can not be read', () async {
    folder.putImage(nameA);
    drafts = null;

    expect((await cleanup().find()).error, CleanupRefused.notAllRead);
  });

  test('refuses if a subfolder can not be read', () async {
    folder.putImage(nameA);
    folder.files.put('sub/a.md', 'text');
    folder.files.unreadableFolders.add(path('sub'));

    expect((await cleanup().find()).error, CleanupRefused.notAllRead);
  });

  test('refuses if the images can not be listed', () async {
    folder.files.failWith = StoreError.ioFailure;

    expect((await cleanup().find()).error, CleanupRefused.storeUnreadable);
  });

  test('a removed image can be brought back', () async {
    folder.putImage(nameA);
    await cleanup().remove((await cleanup().find()).value);

    await folder.store.bringBack({nameA});

    expect(folder.has(nameA), isTrue);
  });
}
