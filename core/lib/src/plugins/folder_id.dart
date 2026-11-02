/// Which folder the user added: the plugin that set it up, by its id, and
/// that plugin's own id for it. Opaque: only the plugin reads its part.
/// Stable on this device; keys the folder's files and app storage.
final class FolderId implements Comparable<FolderId> {
  /// For ids known to be valid, e.g. made in code; anything read from
  /// outside goes through [parse].
  const FolderId(this.plugin, this.folder);

  /// The id of [plugin] and [folder] as read, e.g. from a saved list;
  /// `null` unless both are valid parts ([isPart]).
  static FolderId? parse(String plugin, String folder) =>
      isPart(plugin) && isPart(folder) ? FolderId(plugin, folder) : null;

  /// Whether [part] can be a plugin's or folder's id: lowercase letters
  /// and digits only, so [storageName] is safe as a file name.
  static bool isPart(String part) => _part.hasMatch(part);

  static final _part = RegExp(r'^[a-z0-9]+$');

  /// The id of the plugin that set the folder up.
  final String plugin;

  /// The plugin's own id for the folder.
  final String folder;

  /// One file-safe name for the folder's app storage (drafts, backups).
  /// Its parts are letters and digits ([isPart]), so it never clashes.
  String get storageName => '$plugin-$folder';

  @override
  int compareTo(FolderId other) => storageName.compareTo(other.storageName);

  @override
  bool operator ==(Object other) =>
      other is FolderId && other.plugin == plugin && other.folder == folder;

  @override
  int get hashCode => Object.hash(plugin, folder);

  @override
  String toString() => storageName;
}
