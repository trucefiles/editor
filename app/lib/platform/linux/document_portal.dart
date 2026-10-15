/// Whether [path] lies where the Flatpak document portal shows folders
/// picked through the desktop portal from inside the sandbox.
bool isInDocumentPortal(String path) => _mountPoint.hasMatch(path);

/// The portal's mount point, on the host and inside the sandbox.
final _mountPoint = RegExp(r'^/run/(user/\d+|flatpak)/doc/');
