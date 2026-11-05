import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

void main() {
  final work = folderAt(Directory('/documents/work'), id: 'work');
  final home = folderAt(Directory('/documents/home'), id: 'home');

  FolderFiles scans({
    List<Folder>? folders,
    List<ListedFile> files = const [],
    Map<Folder, StoreError> failed = const {},
    Map<FolderId, List<RelPath>> unreadable = const {},
  }) => contentsFinding(
    files,
    folders: folders ?? [work, home],
    failed: failed,
    unreadable: unreadable,
  ).shown;

  group('covers', () {
    test('documents of folders that were scanned', () {
      expect(
        scans().covers((folder: folderId('work'), path: path('a.md'))),
        isTrue,
      );
    });

    test('no documents of a folder that failed', () {
      final failed = scans(failed: {home: StoreError.ioFailure});

      expect(
        failed.covers((folder: folderId('home'), path: path('a.md'))),
        isFalse,
      );
      expect(
        failed.covers((folder: folderId('work'), path: path('a.md'))),
        isTrue,
      );
    });

    test('no files below a folder inside that could not be read', () {
      final partial = scans(
        unreadable: {
          work.id: [path('private')],
        },
      );

      expect(
        partial.covers((
          folder: folderId('work'),
          path: path('private/a/b.md'),
        )),
        isFalse,
      );
      expect(
        partial.covers((folder: folderId('work'), path: path('privateer.md'))),
        isTrue,
      );
    });
  });

  group('observe', () {
    test('a document found in its listed version', () {
      final file = listedFile(work, version: 3);

      expect(
        scans(files: [file]).observe(file.key),
        isA<Found>().having(
          (found) => found.version,
          'version',
          listedVersion(file),
        ),
      );
    });

    test('a document found, gone, or unknown where the scan was blind', () {
      final found = scans(failed: {home: StoreError.ioFailure});

      expect(
        found.observe((folder: folderId('work'), path: path('a.md'))),
        isA<Gone>(),
      );
      expect(
        found.observe((folder: folderId('home'), path: path('a.md'))),
        isA<Unknown>(),
      );
    });

    test('a file of a folder no longer shown is gone', () {
      expect(
        scans(folders: [work])
            .observe((folder: folderId('home'), path: path('a.md'))),
        isA<Gone>(),
      );
    });
  });

  group('documents', () {
    test('newest first, the same time by folder and path', () {
      final old = listedFile(work, name: 'old.md', modified: DateTime(1));
      final b = listedFile(work, name: 'b.md', modified: DateTime(2));
      final a = listedFile(work, name: 'a.md', modified: DateTime(2));
      final atHome = listedFile(home, name: 'z.md', modified: DateTime(2));

      expect(scans(files: [old, b, atHome, a]).files, [atHome, a, b, old]);
    });

    test('only files of a handled type', () {
      final kept = listedFile(work, name: 'kept/a.md');

      final contents = contentsFinding(
        [
          kept,
          // Listed as a Markdown file would be, but not one by its name.
          ListedFile(
            folder: work,
            path: path('kept/photo.png'),
            type: kept.type,
            version: kept.version,
            modified: kept.modified,
          ),
        ],
        folders: [work],
      );

      expect(contents.shown.files, [kept]);
    });
  });

  test('loaded once every folder was listed, even if that failed', () {
    expect(scans(failed: {home: StoreError.ioFailure}).loaded, isTrue);
    expect(
      FolderFiles(
        FolderState({work.id: const NotListed()}),
        folders: [work],
        types: appFileTypes(),
      ).loaded,
      isFalse,
    );
  });

  test("a file is seen when its folder's listing began", () {
    final early = Moment.now();
    final contents = contentsFinding(
      const [],
      folders: [work, home],
      listedAt: early,
    );

    expect(
      contents.seenAt((folder: folderId('work'), path: path('a.md'))),
      early,
    );
    expect(
      contents.seenAt((folder: folderId('gone'), path: path('a.md'))),
      isNull,
    );
  });

  group('what screens show', () {
    final folders = [work, home];
    final file = listedFile(work, name: 'a.md');

    test('stays the same while the folders found the same', () {
      final before = contentsFinding([file], folders: folders);
      final relisted = Listed(
        (before.state.folders[work.id]! as Listed).found,
        listedAt: Moment.now(),
      );

      final after = FolderContents(
        FolderState({...before.state.folders, work.id: relisted}),
        folders: before.shown.folders,
        types: before.shown.types,
        before: before,
      );

      expect(after.shown, same(before.shown));
      expect(after.seenAt(file.key), same(relisted.listedAt));
    });

    test('is made anew when a folder found something else', () {
      final before = contentsFinding([file], folders: folders);
      final changed = contentsFinding(const [], folders: folders);

      final after = FolderContents(
        changed.state,
        folders: before.shown.folders,
        types: before.shown.types,
        before: before,
      );

      expect(after.shown, isNot(same(before.shown)));
      expect(after.shown.files, isEmpty);
    });

    test('is made anew for other folders', () {
      final before = contentsFinding([file], folders: folders);

      final after = FolderContents(
        before.state,
        folders: [work],
        types: before.shown.types,
        before: before,
      );

      expect(after.shown, isNot(same(before.shown)));
      expect(after.shown.folders, [work]);
    });
  });
}
