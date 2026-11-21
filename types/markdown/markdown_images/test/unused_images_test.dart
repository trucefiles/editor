import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';
import 'package:truce_test_support/truce_test_support.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import 'support.dart';

void main() {
  late ImageFolder folder;
  late Directory draftsDir;
  late FileDrafts drafts;

  setUp(() {
    folder = ImageFolder('f1');
    draftsDir = Directory('${tempFolder().path}/drafts');
    drafts = FileDrafts(draftsDir);
  });

  Future<void> leaveDraft(String file, String text) => drafts.keep(
    Draft(
      DraftHead(
        id: DraftHead.newId(),
        path: path(file),
        of: const OwnDraft(''),
      ),
      utf8.encode(text),
    ),
  );

  /// The cleanup, two hours after the images were put.
  UnusedImages cleanup() => UnusedImages(
    folder.store,
    folder.services,
    drafts: drafts,
    oldDrafts: OldDrafts(draftsDir),
    isDocument: (path) => path.name.endsWith('.md'),
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

  test('an image a table shows stays', () async {
    folder.putImage(nameA);
    folder.files.put(
      'a.md',
      '| a | b |\n|---|---|\n| ![](document-images/$nameA) | x |\n',
    );

    expect((await cleanup().find()).value, isEmpty);
  });

  test('an image a conflict copy or a draft shows stays', () async {
    folder.putImage(nameA);
    folder.putImage(nameB);
    folder.files.put('a.md', 'no images');
    folder.files.put(
      'a.fake-copy-20261101-120000.md',
      '![](document-images/$nameA)',
    );
    await leaveDraft('b.md', '![](document-images/$nameB)');

    expect((await cleanup().find()).value, isEmpty);
  });

  test('an image a draft of an older app version shows stays', () async {
    folder.putImage(nameA);
    File('${draftsDir.path}/1.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({'path': 'b.md', 'text': '![](document-images/$nameA)'}),
      );

    expect((await cleanup().find()).value, isEmpty);
  });

  test('a name only in plain text, code or a file of another type does '
      'not keep an image', () async {
    folder.putImage(nameA);
    folder.files.put('a.md', 'see $nameA, `![](document-images/$nameA)`');
    folder.files.put('b.txt', '![](document-images/$nameA)');
    await leaveDraft('c.txt', '![](document-images/$nameA)');

    expect(names((await cleanup().find()).value), [nameA]);
  });

  test('an image changed in the last hour stays', () async {
    folder.putImage(nameA);

    final fresh = UnusedImages(
      folder.store,
      folder.services,
      drafts: drafts,
      oldDrafts: OldDrafts(draftsDir),
      isDocument: (path) => path.name.endsWith('.md'),
      now: () =>
          DateTime.fromMillisecondsSinceEpoch(0)
              .add(const Duration(minutes: 30)),
    );

    expect((await fresh.find()).value, isEmpty);
  });

  test('an image that came here in the last hour stays, however old', () async {
    folder.putImage(nameA);
    folder.files.arrivals[ImageNames.pathOf(nameA)] =
        DateTime.fromMillisecondsSinceEpoch(0)
            .add(const Duration(hours: 1, minutes: 30));

    expect((await cleanup().find()).value, isEmpty);
  });

  test('refuses if a draft can not be read', () async {
    folder.putImage(nameA);
    await leaveDraft('b.md', 'text');
    File('${draftsDir.path}/2.draft').writeAsStringSync('broken');

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
