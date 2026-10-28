import 'package:truce_core/truce_core.dart';

import 'syncthing_place.dart';
import 'syncthing_sync_check.dart';

/// Syncthing as a sync tool plugin, for folders on this device: recognizes
/// its folders by their marker, keeps conflict copies as files next to
/// their main file, and rewrites a save it might miss (see
/// `SyncthingMtimeWindowStore`).
final class SyncthingTool implements SyncTool {
  const SyncthingTool(this._disk);

  final LocalDisk _disk;

  @override
  String get id => 'syncthing';

  @override
  String get name => 'Syncthing';

  @override
  bool isToolFolder(List<String> names) =>
      SyncthingPlace.rules.isInternalFolder(names);

  @override
  Future<SyncStatus> recognize(Uri address) async => _disk.serves(address)
      ? SyncthingSyncCheck(_disk.markersAt(address)).check()
      : SyncStatus.unknown;

  /// Syncthing keeps old versions in `.stversions` at the root of the
  /// synced folder: out of reach from any folder below it.
  @override
  Future<bool> missesOldVersions(Uri address) async =>
      await recognize(address) == SyncStatus.synced &&
      await _disk.markersAt(address).holds(SyncthingSyncCheck.rootMarker) !=
          true;

  @override
  ToolPlace place(Uri address) => SyncthingPlace(
    _disk.at(address, tempName: SyncthingPlace.rules.tempFileName),
  );
}
