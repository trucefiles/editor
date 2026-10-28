import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/scan/folder_scans.dart';

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

  FolderScans scans({
    List<DocumentFolder>? folders,
    Map<DocumentFolder, StoreError> failed = const {},
    Map<String, List<RelPath>> unreadable = const {},
    Set<DocumentKey> unreadNotes = const {},
  }) => scanFinding(
    const [],
    folders: folders ?? [work, home],
    failed: failed,
    unreadable: unreadable,
    unread: unreadNotes,
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

    test('no document whose file could not be read', () {
      final unread = scans(unreadNotes: {(baseId: 'work', path: path('a.md'))});

      expect(unread.covers((baseId: 'work', path: path('a.md'))), isFalse);
      expect(unread.covers((baseId: 'work', path: path('b.md'))), isTrue);
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
}
