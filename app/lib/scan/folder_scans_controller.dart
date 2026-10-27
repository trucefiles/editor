import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/fresh_runs.dart';
import '../conflicts/folder_conflicts.dart';
import '../documents/document.dart';
import '../documents/document_loader.dart';
import '../documents/draft_recovery.dart';
import '../folders/document_folder.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/folder_services.dart';
import 'folder_scans.dart';

final folderScansProvider =
    AsyncNotifierProvider<FolderScansController, FolderScans>(
      FolderScansController.new,
    );

/// Scans every folder for documents and conflicts, again whenever the folders
/// change, and on [refresh]: changes from the sync tool or other editors
/// show up at the next refresh.
class FolderScansController extends AsyncNotifier<FolderScans> {
  List<DocumentFolder> _folders = const [];
  final Map<String, DocumentLoader> _loaders = {};
  late final _scans = FreshRuns(_scanFolders);

  @override
  Future<FolderScans> build() async {
    _folders = await ref.watch(foldersProvider.future);
    // Documents show only once edits left by the last run are in their files.
    await ref.watch(draftRecoveryProvider.future);
    return _scans.run();
  }

  /// Rescans now, e.g. after a write, when a document opens, when the app
  /// comes back to the foreground, or when the user asks. The scan starts
  /// after this call, so it sees every write made before. Waits for the
  /// folder list and the draft recovery of the build first, so it never
  /// scans too few folders. Does nothing once this controller is disposed,
  /// or if the build failed.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final built = await future.then((_) => true, onError: (_) => false);
    if (!built || !ref.mounted) return;
    final scans = await _scans.run();
    if (ref.mounted) state = AsyncData(scans);
  }

  Future<FolderScans> _scanFolders() async {
    final startedAt = Moment.now();
    final documents = <Document>[];
    final marks = <DocumentKey, DocumentMark>{};
    final subfolders = <String, List<RelPath>>{};
    final conflicts = <FolderConflict>[];
    final failed = <DocumentFolder, StoreError>{};
    final unreadable = <String, List<RelPath>>{};
    final unreadNotes = <DocumentKey>{};
    for (final folder in _folders) {
      // Disposed meanwhile (e.g. the app ends): the result is dropped.
      if (!ref.mounted) break;
      final services = ref.read(folderServicesProvider(folder.location));
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
