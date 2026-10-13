import 'dart:io';

/// Names of the entries in the local folder at the absolute [folderPath];
/// `null` if it cannot be read. Symbolic links are listed, not followed.
Future<Set<String>?> readLocalFolderNames(String folderPath) async {
  try {
    return await Directory(folderPath)
        .list(followLinks: false)
        .map((entity) => entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
        .toSet();
  } on FileSystemException {
    return null;
  }
}
