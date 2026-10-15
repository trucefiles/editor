import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../scan/folder_scans_controller.dart';
import '../sync_tool/folder_services.dart';
import 'all_backups.dart';

final restoreProvider = NotifierProvider.autoDispose
    .family<RestoreController, RestoreState, FolderBackup>(
      RestoreController.new,
    );

/// Shows one backup next to its note's file; the user keeps one of them.
class RestoreController extends Notifier<RestoreState> {
  RestoreController(this._backup);

  final FolderBackup _backup;

  BackupRestore get _restore =>
      ref.read(folderServicesProvider(_backup.folder.location)).restore;

  @override
  RestoreState build() {
    unawaited(_load());
    return const RestoreState();
  }

  /// Keeps the note's file or the backup, then rescans. `null` while the
  /// versions load or a choice runs: nothing was done. After a failure the
  /// versions load again, to show the file as it is now.
  Future<Result<void, ResolveError>?> keep(Resolution resolution) async {
    final RestoreState(:choice, :busy) = state;
    if (choice is! Ok<RestoreChoice, StoreError> || busy) return null;
    state = RestoreState(choice: choice, busy: true);
    final kept = await _restore.keep(choice.value, resolution);
    await ref.read(folderScansProvider.notifier).refresh();
    if (!ref.mounted) return kept;
    ref.invalidate(allBackupsProvider);
    if (kept is Err) await _load();
    return kept;
  }

  Future<void> _load() async {
    final choice = await _restore.load(_backup.backup);
    if (ref.mounted) state = RestoreState(choice: choice);
  }
}

/// What the restore screen shows.
@immutable
final class RestoreState {
  const RestoreState({this.choice, this.busy = false});

  /// The backup and the note's file; `null` while they load.
  final Result<RestoreChoice, StoreError>? choice;

  /// A choice is being carried out; no other may start.
  final bool busy;
}
