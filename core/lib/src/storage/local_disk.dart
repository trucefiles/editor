import '../changes/live_changes.dart';
import '../changes/watched_live_changes.dart';
import 'file_store.dart';
import 'folder_markers.dart';
import 'local_file_store.dart';
import 'subfolder_names.dart';

/// What a sync tool needs to work on base folders on this device, at
/// `file:` addresses: the shared parts every such tool builds on. Built
/// once by the app's platform wiring with the platform's facts; handed to
/// each tool by the sync-tool wiring.
final class LocalDisk {
  const LocalDisk({
    required this.replacesInPlace,
    required this.followsLive,
    required this.seesParents,
  });

  /// See [LocalFileStore.replacesInPlace].
  final bool replacesInPlace;

  /// Whether the platform tells the app about changes to the folder at a
  /// path as other apps make them.
  final bool Function(String folderPath) followsLive;

  /// Whether the app can look at the folders above the folder at a path.
  final bool Function(String folderPath) seesParents;

  /// The base folder at [address], whose atomic writes name their temp
  /// files by [tempName].
  LocalPlace at(Uri address, {required TempFileNamer tempName}) {
    final path = _pathOf(address);
    return LocalPlace(
      files: LocalFileStore(path, tempName, replacesInPlace: replacesInPlace),
      changes: followsLive(path) ? WatchedLiveChanges(path) : null,
      subfolders: LocalSubfolderNames(path),
      markers: markersAt(address),
    );
  }

  /// A look at the base folder at [address] and above, for a tool's
  /// markers only.
  FolderMarkers markersAt(Uri address) {
    final path = _pathOf(address);
    return LocalFolderMarkers(path, seesParents: seesParents(path));
  }

  /// The tools hand over only their own base folders' addresses, so any
  /// other kind of address is a bug.
  static String _pathOf(Uri address) => address.isScheme('file')
      ? address.toFilePath()
      : throw ArgumentError.value(address, 'address', 'not a file: address');
}

/// One base folder on this device, as [LocalDisk.at] builds it.
final class LocalPlace {
  const LocalPlace({
    required this.files,
    required this.changes,
    required this.subfolders,
    required this.markers,
  });

  final FileStore files;

  /// `null` where the platform can't tell changes live.
  final LiveChanges? changes;

  final SubfolderNames subfolders;

  /// For the tool's own markers only.
  final FolderMarkers markers;
}
