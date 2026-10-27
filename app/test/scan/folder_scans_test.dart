import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/scan/folder_scans.dart';

import '../support.dart';

void main() {
  final work = folderAt(Directory('/documents/work'), id: 'work');
  final home = folderAt(Directory('/documents/home'), id: 'home');

  FolderScans scans({
    Map<DocumentFolder, StoreError> failed = const {},
    Map<String, List<RelPath>> unreadable = const {},
    Set<DocumentKey> unreadNotes = const {},
  }) => FolderScans(
    documents: const [],
    marks: const {},
    subfolders: const {},
    conflicts: FolderConflicts(const []),
    failedFolders: failed,
    unreadable: unreadable,
    startedAt: Moment.now(),
    unreadNotes: unreadNotes,
  );

  group('covers', () {
    test('documents of folders that were scanned', () {
      expect(scans().covers((folderId: 'work', path: path('a.md'))), isTrue);
    });

    test('no documents of a folder that failed', () {
      final failed = scans(failed: {home: StoreError.ioFailure});

      expect(failed.covers((folderId: 'home', path: path('a.md'))), isFalse);
      expect(failed.covers((folderId: 'work', path: path('a.md'))), isTrue);
    });

    test('no document whose file could not be read', () {
      final unread = scans(
        unreadNotes: {(folderId: 'work', path: path('a.md'))},
      );

      expect(unread.covers((folderId: 'work', path: path('a.md'))), isFalse);
      expect(unread.covers((folderId: 'work', path: path('b.md'))), isTrue);
    });

    test('no documents below a subfolder that could not be read', () {
      final partial = scans(
        unreadable: {
          work.id: [path('private')],
        },
      );

      expect(
        partial.covers((folderId: 'work', path: path('private/a/b.md'))),
        isFalse,
      );
      expect(
        partial.covers((folderId: 'work', path: path('privateer.md'))),
        isTrue,
      );
    });
  });

  group('observe', () {
    test('a document found, gone, or unknown where the scan was blind', () {
      final found = scans(failed: {home: StoreError.ioFailure});

      expect(
        found.observe((folderId: 'work', path: path('a.md'))),
        isA<Gone>(),
      );
      expect(
        found.observe((folderId: 'home', path: path('a.md'))),
        isA<Unknown>(),
      );
    });
  });
}
