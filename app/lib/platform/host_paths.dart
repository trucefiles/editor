/// Where base folders lie on the host system, to tell whether two overlap.
/// In a sandbox (e.g. Flatpak) the app may see each picked folder at its
/// own unrelated path.
abstract interface class HostPaths {
  /// The host's address of the base folder the app sees at [address];
  /// [address] itself where the host's is unknown, or it is no folder on
  /// this device.
  Future<Uri> of(Uri address);
}

/// Platforms where the app sees folders at their host paths.
final class SameHostPaths implements HostPaths {
  const SameHostPaths();

  @override
  Future<Uri> of(Uri address) async => address;
}
