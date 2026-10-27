import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/documents_owner.dart';
import '../folders/document_folder.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/folder_services.dart';
import 'folder_scanning.dart';
import 'folder_scans.dart';

/// The owner of when the folders are scanned (see [ScansOwner]).
typedef FolderScansOwner = ScansOwner<DocumentFolder, FolderScans>;

/// The app's scans owner, wired: it scans the added folders, the first
/// time once the edits left by the last run are in their files (so no
/// document shows its old text while its draft is pending), and again
/// whenever the folders change. Drafts written after the app started
/// belong to open documents and are left alone.
final folderScansOwnerProvider = Provider<FolderScansOwner>((ref) {
  final scanning = FolderScanning(
    (folder) => ref.read(folderServicesProvider(folder.location)),
    mounted: () => ref.mounted,
  );
  final owner = scansOwner<DocumentFolder, FolderScans>(scanning.scan);
  ref.onDispose(() => unawaited(owner.close()));
  final documents = ref.read(documentsOwnerProvider);
  final startedAt = DateTime.now();
  unawaited(
    ask<DocumentsInput, DraftsRecovered>(
      documents.send,
      documents.events,
      (ticket) => RecoverDrafts(ticket, before: startedAt),
    ).then((_) {
      if (!ref.mounted) return;
      ref.listen(foldersProvider, (_, folders) {
        if (folders.value case final folders?) {
          owner.send(FoldersChanged(folders));
        }
      }, fireImmediately: true);
    }),
  );
  return owner;
});

final folderScansProvider =
    AsyncNotifierProvider<FolderScansController, FolderScans>(
      FolderScansController.new,
    );

/// The latest scan of every folder, for the screens; changes from the sync
/// tool or other editors show up at the next scan.
class FolderScansController extends AsyncNotifier<FolderScans> {
  @override
  Future<FolderScans> build() async {
    final owner = ref.watch(folderScansOwnerProvider);
    final changes = owner.changes.listen((scans) {
      if (scans != null) state = AsyncData(scans);
    });
    ref.onDispose(() => unawaited(changes.cancel()));
    return owner.state ??
        await owner.changes
            .firstWhere((scans) => scans != null)
            .then((scans) => scans!);
  }

  /// Rescans now, e.g. after a write, when a document opens, when the app
  /// comes back to the foreground, or when the user asks; done once a scan
  /// that started after this call has ended, so it sees every write made
  /// before. Waits for the first folders, so it never scans too few. Does
  /// nothing once the app ends.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final owner = ref.read(folderScansOwnerProvider);
    await ask<ScansInput<DocumentFolder, FolderScans>, Fresh>(
      owner.send,
      owner.events,
      Refresh.new,
    );
  }
}
