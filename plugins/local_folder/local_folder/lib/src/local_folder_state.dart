/// One local folder: where the app sees its directory, and where it lies
/// on the host, to compare it with other areas.
final class LocalFolderEntry {
  const LocalFolderEntry({
    required this.id,
    required this.address,
    required this.host,
  });

  final String id;
  final Uri address;

  /// Its host path, resolved once as it was added.
  final Uri host;

  Map<String, Object> toJson() => {
    'id': id,
    'address': '$address',
    'host': '$host',
  };

  static LocalFolderEntry? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'address': final String address,
      'host': final String host,
    } =>
      switch ((_fileUri(address), _fileUri(host))) {
        (final address?, final host?) => LocalFolderEntry(
          id: id,
          address: address,
          host: host,
        ),
        _ => null,
      },
    _ => null,
  };
}

/// What the Local folder plugin knows: its folders. Its blob, as the app
/// saves it:
///
/// ```json
/// {"folders": [{"id": "f1", "address": "file:///home/me/Notes",
///               "host": "file:///home/me/Notes"}]}
/// ```
final class LocalFolderState {
  LocalFolderState([Map<String, LocalFolderEntry> folders = const {}])
    : folders = Map.unmodifiable(folders);

  static final empty = LocalFolderState();

  /// By id, in the order added.
  final Map<String, LocalFolderEntry> folders;

  Object toJson() => {
    'folders': [for (final folder in folders.values) folder.toJson()],
  };

  /// `null` if [json] is not a state [toJson] wrote.
  static LocalFolderState? fromJson(Object? json) {
    if (json case {'folders': final List<Object?> raw}) {
      final folders = raw.map(LocalFolderEntry.fromJson).toList();
      if (folders.contains(null)) return null;
      final state = LocalFolderState({
        for (final folder in folders.nonNulls) folder.id: folder,
      });
      return state.folders.length == folders.length ? state : null;
    }
    return null;
  }
}

Uri? _fileUri(String raw) => switch (Uri.tryParse(raw)) {
  final uri? when uri.isScheme('file') => uri,
  _ => null,
};
