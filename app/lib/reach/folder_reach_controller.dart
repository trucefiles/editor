import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/base_folder.dart';
import '../folders/document_folder.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/base_folder_services.dart';

final folderReachProvider =
    NotifierProvider.family<FolderReachController, Reach, BaseFolder>(
      FolderReachController.new,
    );

/// Whether a [BaseFolder] can be reached, kept current
/// as its file accesses go. No UI.
class FolderReachController extends Notifier<Reach> {
  FolderReachController(this._base);

  final BaseFolder _base;

  @override
  Reach build() {
    final reach = ref.watch(baseFolderServicesProvider(_base)).reach;
    final changes = reach.changes.listen((reach) => state = reach);
    ref.onDispose(() => unawaited(changes.cancel()));
    return reach.state;
  }

  /// The reach once a running check and its retries are over.
  Future<Reach> settled() async {
    final reach = ref.read(baseFolderServicesProvider(_base)).reach;
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
final retryingFoldersProvider = Provider<List<DocumentFolder>>(
  (ref) => [
    for (final folder
        in ref.watch(loadedFoldersProvider).value ?? <DocumentFolder>[])
      if (ref.watch(folderReachProvider(folder.base)) == Reach.retrying) folder,
  ],
);
