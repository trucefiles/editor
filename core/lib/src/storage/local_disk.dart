import '../changes/live_changes.dart';
import '../changes/watched_live_changes.dart';
import 'disk_areas.dart';
import 'file_store.dart';
import 'folder_markers.dart';
import 'host_paths.dart';
import 'local_file_store.dart';
import 'subfolder_names.dart';

/// The local-disk service: what a plugin needs to work on folders on this
/// device, at `file:` addresses. Built once by the app's platform wiring
/// with the platform's facts; handed to each disk plugin by the plugin
/// wiring.
final class LocalDisk {
  LocalDisk({
    required this.replacesInPlace,
    required this.followsLive,
    required this.seesParents,
    required this._hostPaths,
  });

  /// See [LocalFileStore.replacesInPlace].
  final bool replacesInPlace;

  /// Whether the platform tells the app about changes to the folder at a
  /// path as other apps make them.
  final bool Function(String folderPath) followsLive;

  /// Whether the app can look at the folders above the folder at a path.
  final bool Function(String folderPath) seesParents;

  final HostPaths _hostPaths;

  /// The areas the disk plugins claim, with the one overlap rule.
  final areas = DiskAreas();

  /// Whether [address] is a folder on this device, which this service
  /// opens.
  bool serves(Uri address) => address.isScheme('file');

  /// The host's address of the folder the app sees at [address] (see
  /// [HostPaths]).
  Future<Uri> hostPathOf(Uri address) => _hostPaths.of(address);

  /// The directory at [address], whose atomic writes name their temp files
  /// by [tempName]: one file store per directory.
  LocalFolder open(Uri address, {required TempFileNamer tempName}) {
    final path = _pathOf(address);
    return LocalFolder(
      files: LocalFileStore(path, tempName, replacesInPlace: replacesInPlace),
      changes: followsLive(path) ? WatchedLiveChanges(path) : null,
    );
  }

  /// A look at the folder at [address] and above, for a plugin's markers
  /// only.
  FolderMarkers markersAt(Uri address) {
    final path = _pathOf(address);
    return LocalFolderMarkers(path, seesParents: seesParents(path));
  }

  /// The folder names in the folder at [address], e.g. for an add page's
  /// tree.
  SubfolderNames subfoldersAt(Uri address) =>
      LocalSubfolderNames(_pathOf(address));

  /// Plugins hand over only addresses it [serves], so any other is a bug.
  String _pathOf(Uri address) => serves(address)
      ? address.toFilePath()
      : throw ArgumentError.value(address, 'address', 'not a file: address');
}

/// One directory on this device, as [LocalDisk.open] gives it.
final class LocalFolder {
  const LocalFolder({required this.files, required this.changes});

  final FileStore files;

  /// `null` where the platform can't tell changes live.
  final LiveChanges? changes;
}
