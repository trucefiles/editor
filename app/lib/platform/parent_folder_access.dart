/// Whether the app can read the parent folders of the folder at
/// [folderPath].
///
/// Not for a folder handed in through the Flatpak document portal: the
/// sandbox sees only the picked folder, not what lies above it.
bool canReadParents(String folderPath) => !_documentPortal.hasMatch(folderPath);

/// Where the document portal mounts picked folders inside the sandbox.
final _documentPortal = RegExp(r'^/run/(user/\d+|flatpak)/doc/');
