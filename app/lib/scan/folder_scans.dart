import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../documents/document.dart';
import '../documents/document_version.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';

/// What the last scan of all folders found.
final class FolderScans {
  FolderScans({
    required this.folders,
    required this.documents,
    required this.marks,
    required this.subfolders,
    required this.conflicts,
    required this.failedFolders,
    required this.unreadable,
    required this.startedAt,
    this.gone = const {},
    this.unreadNotes = const {},
  });

  /// The folders scanned.
  final List<DocumentFolder> folders;

  /// Newest first.
  final List<Document> documents;

  /// Colors; documents without a mark are left out.
  final Map<DocumentKey, DocumentMark> marks;

  /// Each folder's subfolders by folder id, sorted by path: those it
  /// shows, its selected subfolders too.
  final Map<String, List<RelPath>> subfolders;

  final FolderConflicts conflicts;

  /// Folders that could not be scanned; they have no documents or conflicts.
  final Map<DocumentFolder, StoreError> failedFolders;

  /// Each folder's subfolders that could not be read, by folder id; only
  /// folders that have some.
  final Map<String, List<RelPath>> unreadable;

  /// Each folder's selected subfolders that are gone, by folder id; only
  /// folders that have some. Never created again by the app.
  final Map<String, List<RelPath>> gone;

  /// When the scan began; files written later may show older versions.
  final Moment startedAt;

  /// Documents whose files were listed but could not be read in their current
  /// version (e.g. no access for a moment, no longer text, gone right
  /// after the listing): [documents] holds their last version, if any.
  final Set<DocumentKey> unreadNotes;

  DocumentMark markOf(DocumentKey key) => marks[key] ?? DocumentMark.none;

  /// The subfolders of folder [folderId], empty ones too, sorted by path.
  List<RelPath> subfoldersOf(String folderId) =>
      subfolders[folderId] ?? const [];

  /// Whether this scan could see the document at [key] as it is, if it
  /// exists: a folder shows it, its base folder was scanned, no subfolder
  /// above it was unreadable, and its file was read. If not, a document
  /// missing from [documents] may still exist, and one in [documents] may
  /// be older than its file.
  bool covers(DocumentKey key) =>
      folders.folderOf(key.baseId, key.path) != null &&
      !unreadNotes.contains(key) &&
      !failedFolders.keys.any((folder) => folder.base.id == key.baseId) &&
      !folders
          .where((folder) => folder.base.id == key.baseId)
          .expand((folder) => unreadable[folder.id] ?? const <RelPath>[])
          .any((folder) => Selection.isInside(key.path, folder));

  Document? findNote(DocumentKey key) => _byKey[key];

  late final Map<DocumentKey, Document> _byKey = {
    for (final document in documents) document.key: document,
  };

  /// What this scan tells of the document at [key]: found in a version,
  /// gone, or unknown where the scan could not see it (see [covers]).
  /// A document of a base folder no folder shows any more is gone.
  Observation observe(DocumentKey key) => switch (findNote(key)) {
    _ when !folders.any((folder) => folder.base.id == key.baseId) =>
      const Gone(),
    _ when !covers(key) => const Unknown(),
    final found? => Found(found.seen),
    null => const Gone(),
  };
}
