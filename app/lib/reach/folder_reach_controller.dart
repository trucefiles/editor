import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folders_controller.dart';
import '../folders/note_folder.dart';
import '../sync_tool/folder_services.dart';

final folderReachProvider =
    NotifierProvider.family<FolderReachController, Reach, FolderLocation>(
      FolderReachController.new,
    );

/// Whether the folder at a [FolderLocation] can be reached, kept current
/// as its file accesses go. No UI.
class FolderReachController extends Notifier<Reach> {
  FolderReachController(this._location);

  final FolderLocation _location;

  @override
  Reach build() {
    final reach = ref.watch(folderServicesProvider(_location)).reach;
    final changes = reach.changes.listen((reach) => state = reach);
    ref.onDispose(() => unawaited(changes.cancel()));
    return reach.state;
  }
}

/// The folders that are [Reach.retrying] right now.
final retryingFoldersProvider = Provider<List<NoteFolder>>(
  (ref) => [
    for (final folder in ref.watch(foldersProvider).value ?? <NoteFolder>[])
      if (ref.watch(folderReachProvider(folder.location)) == Reach.retrying)
        folder,
  ],
);
