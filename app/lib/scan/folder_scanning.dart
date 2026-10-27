import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../documents/document.dart';
import '../documents/document_loader.dart';
import '../folders/document_folder.dart';
import '../sync_tool/folder_services.dart';
import 'folder_scans.dart';

/// Scans folders for documents, marks and conflicts: the scans owner's
/// effect. Keeps one loader per folder, so documents unchanged since the
/// last scan are not read again.
final class FolderScanning {
  /// [servicesOf] gives each folder's services; [mounted] tells whether
  /// they can still be had (not once the app ends).
  FolderScanning(this._servicesOf, {required this._mounted});

  final FolderServices Function(DocumentFolder folder) _servicesOf;
  final bool Function() _mounted;
  final Map<String, DocumentLoader> _loaders = {};

  /// What [folders] hold now.
  Future<FolderScans> scan(List<DocumentFolder> folders) async {
    final startedAt = Moment.now();
    final documents = <Document>[];
    final marks = <DocumentKey, DocumentMark>{};
    final subfolders = <String, List<RelPath>>{};
    final conflicts = <FolderConflict>[];
    final failed = <DocumentFolder, StoreError>{};
    final unreadable = <String, List<RelPath>>{};
    final unreadNotes = <DocumentKey>{};
    for (final folder in folders) {
      // The app ends: the result goes nowhere.
      if (!_mounted()) break;
      final services = _servicesOf(folder);
      switch (await services.scanner.scan()) {
        case Ok(value: final scan):
          final loaded = await _loaderFor(
            folder,
            services,
          ).load(folder, scan.files);
          documents.addAll(loaded.documents);
          unreadNotes.addAll([
            for (final path in loaded.unread) (folderId: folder.id, path: path),
          ]);
          marks.addAll(await _marksOf(folder, services));
          subfolders[folder.id] = [...scan.subfolders]
            ..sort((a, b) => a.value.compareTo(b.value));
          conflicts.addAll(
            scan.conflicts.map((conflict) => FolderConflict(folder, conflict)),
          );
          if (scan.unreadable.isNotEmpty) {
            unreadable[folder.id] = scan.unreadable;
          }
        case Err(:final error):
          failed[folder] = error;
      }
    }
    documents.sort(_newestFirst);
    return FolderScans(
      documents: documents,
      marks: marks,
      subfolders: subfolders,
      conflicts: FolderConflicts(conflicts),
      failedFolders: failed,
      unreadable: unreadable,
      startedAt: startedAt,
      unreadNotes: unreadNotes,
    );
  }

  /// Newest first; documents with the same time by folder and path, so the
  /// order never changes between scans of the same files.
  static int _newestFirst(Document a, Document b) {
    final byTime = b.modified.compareTo(a.modified);
    if (byTime != 0) return byTime;
    final byFolder = a.folder.id.compareTo(b.folder.id);
    return byFolder != 0 ? byFolder : a.path.value.compareTo(b.path.value);
  }

  /// The folder's marks; none if they cannot be read, as they only help.
  Future<Map<DocumentKey, DocumentMark>> _marksOf(
    DocumentFolder folder,
    FolderServices services,
  ) async => switch (await services.marks.load()) {
    Ok(:final value) => {
      for (final MapEntry(key: path, value: mark) in value.entries)
        (folderId: folder.id, path: path): mark,
    },
    Err() => const {},
  };

  DocumentLoader _loaderFor(DocumentFolder folder, FolderServices services) =>
      _loaders.putIfAbsent(folder.id, () => DocumentLoader(services));
}
