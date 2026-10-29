import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

void main() {
  final work = folderAt(
    Directory('/documents/work'),
    id: 'work',
    baseId: 'work',
  );
  final home = folderAt(
    Directory('/documents/home'),
    id: 'home',
    baseId: 'home',
  );

  FolderContents scans({
    List<DocumentFolder>? folders,
    List<Document> documents = const [],
    Map<DocumentFolder, StoreError> failed = const {},
    Map<String, List<RelPath>> unreadable = const {},
  }) => contentsFinding(
    documents,
    folders: folders ?? [work, home],
    failed: failed,
    unreadable: unreadable,
  );

  group('covers', () {
    test('documents of folders that were scanned', () {
      expect(scans().covers((baseId: 'work', path: path('a.md'))), isTrue);
    });

    test('no documents of a folder that failed', () {
      final failed = scans(failed: {home: StoreError.ioFailure});

      expect(failed.covers((baseId: 'home', path: path('a.md'))), isFalse);
      expect(failed.covers((baseId: 'work', path: path('a.md'))), isTrue);
    });

    test('no documents below a subfolder that could not be read', () {
      final partial = scans(
        unreadable: {
          work.id: [path('private')],
        },
      );

      expect(
        partial.covers((baseId: 'work', path: path('private/a/b.md'))),
        isFalse,
      );
      expect(
        partial.covers((baseId: 'work', path: path('privateer.md'))),
        isTrue,
      );
    });
  });

  test('no documents no folder shows', () {
    final narrowed = scans(
      folders: [
        work.copyWith(selection: Selection.of([path('kept')])),
        home,
      ],
    );

    expect(narrowed.covers((baseId: 'work', path: path('kept/a.md'))), isTrue);
    expect(
      narrowed.covers((baseId: 'work', path: path('other/a.md'))),
      isFalse,
    );
  });

  group('observe', () {
    test('a document found in its listed version', () {
      final document = listedDocument(work, version: 3);

      expect(
        scans(documents: [document]).observe(document.key),
        isA<Found>().having(
          (found) => found.version,
          'version',
          listedVersion(document),
        ),
      );
    });

    test('a document found, gone, or unknown where the scan was blind', () {
      final found = scans(failed: {home: StoreError.ioFailure});

      expect(found.observe((baseId: 'work', path: path('a.md'))), isA<Gone>());
      expect(
        found.observe((baseId: 'home', path: path('a.md'))),
        isA<Unknown>(),
      );
    });

    test('a document of a base folder no folder shows any more is gone', () {
      expect(
        scans(folders: [work]).observe((baseId: 'home', path: path('a.md'))),
        isA<Gone>(),
      );
    });
  });

  group('documents', () {
    test('newest first, the same time by base folder and path', () {
      final old = listedDocument(work, name: 'old.md', modified: DateTime(1));
      final b = listedDocument(work, name: 'b.md', modified: DateTime(2));
      final a = listedDocument(work, name: 'a.md', modified: DateTime(2));
      final atHome = listedDocument(home, name: 'z.md', modified: DateTime(2));

      expect(scans(documents: [old, b, atHome, a]).documents, [
        atHome,
        a,
        b,
        old,
      ]);
    });

    test('only files of a handled type that a folder shows', () {
      final narrowed = work.copyWith(selection: Selection.of([path('kept')]));
      final kept = listedDocument(narrowed, name: 'kept/a.md');

      final contents = contentsFinding(
        [
          kept,
          listedDocument(narrowed, name: 'other/a.md'),
          // Listed as a Markdown file would be, but not one by its name.
          Document(
            folder: narrowed,
            path: path('kept/photo.png'),
            type: kept.type,
            version: kept.version,
            modified: kept.modified,
          ),
        ],
        folders: [narrowed],
      );

      expect(contents.documents, [kept]);
    });
  });

  test('loaded once every base folder was listed, even if that failed', () {
    expect(scans(failed: {home: StoreError.ioFailure}).loaded, isTrue);
    expect(
      FolderContents(
        FolderState({'work': const NotListed()}),
        folders: [work],
        types: appDocumentTypes(),
      ).loaded,
      isFalse,
    );
  });

  test('listed at the start of the oldest listing', () {
    final early = Moment.now();
    final contents = FolderContents(
      FolderState({
        ...contentsFinding(
          const [],
          folders: [work],
          listedAt: early,
        ).state.bases,
        ...contentsFinding(const [], folders: [home]).state.bases,
      }),
      folders: [work, home],
      types: appDocumentTypes(),
    );

    expect(contents.listedAt, early);
    expect(contents.seenAt((baseId: 'work', path: path('a.md'))), early);
  });
}
