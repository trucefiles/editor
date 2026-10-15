import 'linux/document_portal.dart';

/// Whether the app can read the parent folders of the folder at
/// [folderPath].
///
/// Not for a folder handed in through the Flatpak document portal: the
/// sandbox sees only the picked folder, not what lies above it.
bool canReadParents(String folderPath) => !isInDocumentPortal(folderPath);
