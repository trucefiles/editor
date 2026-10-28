import 'package:truce_core/truce_core.dart';

import 'plain_conflict_names.dart';
import 'plain_folder_rules.dart';

/// A folder synced by no tool, or by one the app doesn't know: the app
/// keeps a save that can't land as a conflict copy next to its document
/// ([PlainConflictNames]), and shows those copies as conflicts.
///
/// Recognizes nothing: any folder can be plain, so the user picks it.
final class PlainFolderTool implements SyncTool {
  const PlainFolderTool();

  static const _names = PlainConflictNames();

  @override
  String get id => 'plain';

  @override
  SyncAdapter get rules => const PlainFolderRules();

  @override
  Future<SyncStatus> recognize(FolderMarkers markers) async =>
      SyncStatus.unknown;

  /// No tool keeps old versions that the app could reach.
  @override
  Future<bool> missesOldVersions(FolderMarkers markers) async => false;

  @override
  SyncedFolder open(
    FileStore store, {
    required FileFilter shown,
    required FolderMarkers markers,
    required Duration? Function() pollInterval,
  }) => SyncedFolder(
    store: store,
    scanner: NamedCopiesScanner(store, shown, _names),
    conflicts: NamedConflictSource(store, _names),
    notices: _PolledNotices(pollInterval),
    followed: WithConflictCopies(shown, _names),
  );
}

/// A plain folder's only notice: that its changes are polled, while
/// [_pollInterval] gives an interval.
final class _PolledNotices implements FolderNotices {
  const _PolledNotices(this._pollInterval);

  final Duration? Function() _pollInterval;

  @override
  Future<List<FolderNotice>> check() async => [
    if (_pollInterval() case final interval?) PolledNotice(interval),
  ];
}
