import 'dart:math';

final _random = Random.secure();

/// A new random id for a folder a plugin sets up: 12 hex digits, so it
/// is safe in file names (`FolderId.storageName`).
String newPluginFolderId() =>
    List.generate(12, (_) => _random.nextInt(16).toRadixString(16)).join();
