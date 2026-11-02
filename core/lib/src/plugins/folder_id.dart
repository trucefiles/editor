/// Which folder the user added: the plugin that set it up, by its id, and
/// that plugin's own id for it. Opaque: only the plugin reads its part.
/// Stable on this device; keys the folder's files and app storage.
final class FolderId implements Comparable<FolderId> {
  const FolderId(this.plugin, this.folder);

  /// The id of the plugin that set the folder up.
  final String plugin;

  /// The plugin's own id for the folder.
  final String folder;

  /// One file-safe name for the folder's app storage (drafts, backups).
  /// Plugin and folder ids are letters and digits, so it never clashes.
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
