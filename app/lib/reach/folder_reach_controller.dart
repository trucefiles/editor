import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folders/folders_controller.dart';
import '../folders/open_folders_wiring.dart';

final folderReachProvider =
    NotifierProvider.family<FolderReachController, Reach, FolderId>(
      FolderReachController.new,
    );

/// Whether a folder can be reached, kept current as its file accesses
/// go. No UI.
class FolderReachController extends Notifier<Reach> {
  FolderReachController(this._folder);

  final FolderId _folder;

  @override
  Reach build() {
    final reach = ref.watch(folderServicesProvider(_folder)).reach;
    final changes = reach.changes.listen((reach) => state = reach);
    ref.onDispose(() => unawaited(changes.cancel()));
    return reach.state;
  }

  /// The reach once a running check and its retries are over.
  Future<Reach> settled() async {
    final reach = ref.read(folderServicesProvider(_folder)).reach;
    final settled = await ask<ReachInput, Settled>(
      reach.send,
      reach.events,
      Settle.new,
    );
    // The folder was removed meanwhile.
    return settled?.reach ?? reach.state;
  }
}

/// The folders that are [Reach.retrying] right now.
final retryingFoldersProvider = Provider<List<Folder>>(
  (ref) => [
    for (final folder in ref.watch(foldersProvider).value ?? <Folder>[])
      if (ref.watch(folderReachProvider(folder.id)) == Reach.retrying) folder,
  ],
);
