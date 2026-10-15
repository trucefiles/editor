/// Whether the app may open folders by path. Android needs the all-files
/// permission for that; other platforms grant access per picked folder.
abstract interface class StorageAccess {
  Future<bool> isGranted();

  /// Opens the system page where the user grants access. The answer comes
  /// back later; check [isGranted] again when the app is shown.
  Future<void> request();
}

/// Platforms where picking a folder is enough.
final class GrantedStorageAccess implements StorageAccess {
  const GrantedStorageAccess();

  @override
  Future<bool> isGranted() async => true;

  @override
  Future<void> request() async {}
}
