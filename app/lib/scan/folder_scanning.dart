import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../documents/document.dart';
import '../documents/document_loader.dart';
import '../file_types/document_types.dart';
import '../folders/base_folder.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';
import '../sync_tool/base_folder_services.dart';
import 'folder_scans.dart';

/// Scans folders for documents, marks and conflicts: the scans owner's
/// effect. Scans each base folder once, for all its folders; each file
/// shows in the folder that shows its path. Keeps one loader per base
/// folder, so documents unchanged since the last scan are not read again.
final class FolderScanning {
  /// [servicesOf] gives each base folder's services; [mounted] tells
  /// whether they can still be had (not once the app ends).
  FolderScanning(this._servicesOf, this._types, {required this._mounted});

  final BaseFolderServices Function(BaseFolder base) _servicesOf;
  final DocumentTypes _types;
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
    final gone = <String, List<RelPath>>{};
    final unreadNotes = <DocumentKey>{};
    for (final base in {for (final folder in folders) folder.base}) {
      // The app ends: the result goes nowhere.
      if (!_mounted()) break;
      final shown = [
        for (final folder in folders)
          if (folder.base == base) folder,
      ];
      DocumentFolder? folderOf(RelPath path) => shown.folderOf(base.id, path);
      final services = _servicesOf(base);
      switch (await services.scanner.scan()) {
        case Ok(value: final scan):
          final loaded = await _loaderFor(base)
              .load(services.store, scan.files, folderOf);
          documents.addAll(loaded.documents);
          unreadNotes.addAll([
            for (final path in loaded.unread) (baseId: base.id, path: path),
          ]);
          marks.addAll(await _marksOf(base, services, folderOf));
          conflicts.addAll([
            for (final conflict in scan.conflicts)
              if (folderOf(conflict.mainPath) case final folder?)
                FolderConflict(folder, conflict),
          ]);
          for (final folder in shown) {
            subfolders[folder.id] = [
              for (final subfolder in scan.subfolders)
                if (folder.covers(subfolder)) subfolder,
            ]..sort((a, b) => a.value.compareTo(b.value));
            final notRead = [
              for (final subfolder in scan.unreadable)
                if (folder.selection.reaches(subfolder)) subfolder,
            ];
            if (notRead.isNotEmpty) unreadable[folder.id] = notRead;
            final goneHere = _goneOf(folder, scan);
            if (goneHere.isNotEmpty) gone[folder.id] = goneHere;
          }
        case Err(:final error):
          failed.addAll({for (final folder in shown) folder: error});
      }
    }
    documents.sort(_newestFirst);
    return FolderScans(
      folders: folders,
      documents: documents,
      marks: marks,
      subfolders: subfolders,
      conflicts: FolderConflicts(conflicts),
      failedFolders: failed,
      unreadable: unreadable,
      gone: gone,
      startedAt: startedAt,
      unreadNotes: unreadNotes,
    );
  }

  /// [folder]'s selected subfolders that [scan] didn't find, though it
  /// could read the way to them.
  static List<RelPath> _goneOf(DocumentFolder folder, FolderScan scan) =>
      switch (folder.selection) {
        WholeFolder() => const [],
        Subfolders(:final roots) => [
          for (final root in roots)
            if (!scan.subfolders.contains(root) &&
                !scan.unreadable.any(
                  (folder) =>
                      folder == root || Selection.isInside(root, folder),
                ))
              root,
        ]..sort((a, b) => a.value.compareTo(b.value)),
      };

  /// Newest first; documents with the same time by base folder and path,
  /// so the order never changes between scans of the same files.
  static int _newestFirst(Document a, Document b) {
    final byTime = b.modified.compareTo(a.modified);
    if (byTime != 0) return byTime;
    final byBase = a.folder.base.id.compareTo(b.folder.base.id);
    return byBase != 0 ? byBase : a.path.value.compareTo(b.path.value);
  }

  /// The marks of the documents a folder shows; none if they cannot be
  /// read, as they only help.
  Future<Map<DocumentKey, DocumentMark>> _marksOf(
    BaseFolder base,
    BaseFolderServices services,
    DocumentFolder? Function(RelPath path) folderOf,
  ) async => switch (await services.marks.load()) {
    Ok(:final value) => {
      for (final MapEntry(key: path, value: mark) in value.entries)
        if (folderOf(path) != null) (baseId: base.id, path: path): mark,
    },
    Err() => const {},
  };

  DocumentLoader _loaderFor(BaseFolder base) =>
      _loaders.putIfAbsent(base.id, () => DocumentLoader(_types));
}
