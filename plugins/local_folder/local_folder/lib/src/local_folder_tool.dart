import 'package:truce_core/truce_core.dart';

import 'local_folder_place.dart';

/// A folder on this device synced by no tool, or by one the app doesn't
/// know: the app keeps a save that can't land as a conflict copy next to
/// its file (`LocalConflictNames`), and shows those copies as
/// conflicts.
///
/// Recognizes nothing: any folder can be plain, so the user picks it.
final class LocalFolderTool implements SyncTool {
  const LocalFolderTool(this._disk);

  final LocalDisk _disk;

  @override
  String get id => 'plain';

  @override
  String get name => 'Local folder';

  @override
  bool isToolFolder(Uri address) =>
      LocalFolderPlace.rules.isInternalFolder(address.pathSegments);

  @override
  Future<SyncStatus> recognize(Uri address) async => SyncStatus.unknown;

  /// No tool keeps old versions that the app could reach.
  @override
  Future<bool> missesOldVersions(Uri address) async => false;

  @override
  ToolPlace place(Uri address) => LocalFolderPlace(
    _disk.at(address, tempName: LocalFolderPlace.rules.tempFileName),
  );
}
