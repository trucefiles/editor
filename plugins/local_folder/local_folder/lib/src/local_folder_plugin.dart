import 'package:truce_core/truce_core.dart';

import 'local_directory.dart';
import 'local_folder_state.dart';

/// Why a picked directory can't be a local folder.
enum LocalPickRefused {
  /// It lies in a hidden folder, e.g. a sync tool's own version folder.
  hidden,

  /// It lies at, inside or around a folder already added.
  overlaps,
}

/// A folder on this device synced by no tool, or by one the app doesn't
/// know: any directory the user picks. The app keeps a save that can't
/// land as a conflict copy next to its file (`LocalConflictNames`), and
/// shows those copies as conflicts. Its folders are its areas on [_disk].
final class LocalFolderPlugin implements FolderPlugin {
  LocalFolderPlugin(this._disk, {String Function()? newId})
    : _newId = newId ?? newPluginFolderId;

  final LocalDisk _disk;
  final String Function() _newId;
  LocalFolderState _state = LocalFolderState.empty;

  @override
  String get id => 'local';

  @override
  String get name => 'Local folder';

  @override
  String get helpLine => 'No sync in place';

  @override
  bool load(Object? blob) {
    final state = blob == null
        ? LocalFolderState.empty
        : LocalFolderState.fromJson(blob);
    _set(state ?? LocalFolderState.empty);
    return state != null;
  }

  @override
  Object? get blob => _state.toJson();

  @override
  List<PluginFolder> get folders => [
    for (final folder in _state.folders.values) _pluginFolder(folder),
  ];

  /// [picked] as a folder to set up, or why it can't be one.
  Future<Result<PluginFolderCandidate, LocalPickRefused>> candidateFor(
    Uri picked,
  ) async {
    final host = await _disk.hostPathOf(picked);
    if ([picked, host].any(liesInHidden)) {
      return const Err(LocalPickRefused.hidden);
    }
    if (_clashesIn(_state, host)) return const Err(LocalPickRefused.overlaps);
    return Ok(
      PluginFolderCandidate(
        defaultName: lastSegment(picked),
        location: shownAddress(host),
        detail: {'address': '$picked', 'host': '$host'},
      ),
    );
  }

  @override
  Result<List<PluginFolder>, AddRefused> add(
    List<PluginFolderCandidate> candidates,
  ) {
    var state = _state;
    final added = <LocalFolderEntry>[];
    for (final candidate in candidates) {
      final folder = _entryOf(candidate.detail);
      if (_clashesIn(state, folder.host)) return const Err(AddRefused.overlaps);
      added.add(folder);
      state = LocalFolderState({...state.folders, folder.id: folder});
    }
    _set(state);
    return Ok([for (final folder in added) _pluginFolder(folder)]);
  }

  @override
  void forget(String id) =>
      _set(LocalFolderState({..._state.folders}..remove(id)));

  @override
  RawFolder open(String id) => LocalDirectory(
    _disk.open(
      _state.folders[id]!.address,
      tempName: LocalDirectory.rules.tempFileName,
    ),
  );

  void _set(LocalFolderState state) {
    _state = state;
    _disk.areas.claim(id, [
      for (final folder in state.folders.values) folder.host,
    ]);
  }

  /// Whether a folder at [host] would lie at, inside or around one of
  /// [state]'s or another plugin's area.
  bool _clashesIn(LocalFolderState state, Uri host) =>
      _disk.areas.clashes(id, host) ||
      state.folders.values.any((folder) => nests(folder.host, host));

  /// Only ever of a candidate this plugin made, so anything else is a bug.
  LocalFolderEntry _entryOf(Object detail) => switch (detail) {
    {'address': final String address, 'host': final String host} =>
      LocalFolderEntry(
        id: _newId(),
        address: Uri.parse(address),
        host: Uri.parse(host),
      ),
    _ => throw ArgumentError.value(detail, 'detail', 'not a local pick'),
  };

  static PluginFolder _pluginFolder(LocalFolderEntry folder) =>
      PluginFolder(id: folder.id, location: shownAddress(folder.host));
}
