import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../documents/document.dart';
import '../documents/document_version.dart';
import '../file_types/document_types.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';

/// What the added folders hold now, as the screens show it: their
/// documents (listed, never their texts), marks, subfolders, conflicts,
/// and what could not be seen. Worked out once from the base folders'
/// state; questions are lookups on it.
final class FolderContents {
  FolderContents(this.state, {required this.folders, required this.types});

  /// What the base folders hold.
  final FolderState state;

  /// The folders the user added.
  final List<DocumentFolder> folders;

  final DocumentTypes types;

  /// Whether every folder's base folder was listed at least once, even if
  /// that failed: until then, what shows may be missing documents.
  late final bool loaded = folders.every(
    (folder) => state.bases[folder.base.id] is! NotListed?,
  );

  /// Every document a folder shows, newest first; documents with the same
  /// time by base folder and path, so the order never changes between
  /// listings of the same files.
  late final List<Document> documents = [
    for (final MapEntry(key: baseId, value: base) in state.bases.entries)
      if (base case Listed(:final files))
        for (final entry in files.values) ?_documentOf(baseId, entry),
  ]..sort(_newestFirst);

  Document? _documentOf(String baseId, FileEntry entry) {
    final folder = folders.folderOf(baseId, entry.path);
    final type = types.of(entry.path)?.support;
    if (folder == null || type == null) return null;
    return Document(
      folder: folder,
      path: entry.path,
      type: type,
      version: entry.version,
      modified: entry.modified,
    );
  }

  static int _newestFirst(Document a, Document b) {
    final byTime = b.modified.compareTo(a.modified);
    if (byTime != 0) return byTime;
    final byBase = a.folder.base.id.compareTo(b.folder.base.id);
    return byBase != 0 ? byBase : a.path.value.compareTo(b.path.value);
  }

  late final Map<DocumentKey, Document> _byKey = {
    for (final document in documents) document.key: document,
  };

  Document? findNote(DocumentKey key) => _byKey[key];

  /// The colors of the documents the folders show; unmarked ones left
  /// out.
  late final Map<DocumentKey, DocumentMark> marks = {
    for (final MapEntry(key: baseId, value: base) in state.bases.entries)
      if (base case Listed(:final marks))
        for (final MapEntry(key: path, value: mark) in marks.marks.entries)
          if (folders.folderOf(baseId, path) != null)
            (baseId: baseId, path: path): mark,
  };

  DocumentMark markOf(DocumentKey key) => marks[key] ?? DocumentMark.none;

  /// The pending conflicts of what the folders show.
  late final FolderConflicts conflicts = FolderConflicts([
    for (final MapEntry(key: baseId, value: base) in state.bases.entries)
      if (base case Listed(:final conflicts))
        for (final conflict in conflicts.values)
          if (folders.folderOf(baseId, conflict.mainPath) case final folder?
              when types.handles(conflict.mainPath))
            FolderConflict(folder, conflict),
  ]);

  /// The subfolders of folder [folderId], empty ones too, its selected
  /// subfolders among them, sorted by path.
  List<RelPath> subfoldersOf(String folderId) =>
      switch ((_folder(folderId), _listedOf(folderId))) {
        (final folder?, final base?) => [
          for (final subfolder in base.subfolders)
            if (folder.covers(subfolder)) subfolder,
        ]..sort((a, b) => a.value.compareTo(b.value)),
        _ => const [],
      };

  /// The folders whose base folder could not be listed, and why.
  late final Map<DocumentFolder, StoreError> failedFolders = {
    for (final folder in folders)
      if (state.bases[folder.base.id] case ListingFailed(:final error))
        folder: error,
  };

  /// Each folder's subfolders that could not be read, by folder id; only
  /// folders that have some.
  late final Map<String, List<RelPath>> unreadable = {
    for (final folder in folders)
      if (_listedOf(folder.id) case final base?)
        if ([
              for (final subfolder in base.unreadable)
                if (folder.selection.reaches(subfolder)) subfolder,
            ]
            case final subfolders when subfolders.isNotEmpty)
          folder.id: subfolders,
  };

  /// Each folder's selected subfolders that are gone, by folder id; only
  /// folders that have some. Never created again by the app.
  late final Map<String, List<RelPath>> gone = {
    for (final folder in folders)
      if ((folder.selection, _listedOf(folder.id)) case (
        Subfolders(:final roots),
        final base?,
      ))
        if ([
              for (final root in roots)
                if (!base.subfolders.contains(root) && base.sees(root)) root,
            ]..sort((a, b) => a.value.compareTo(b.value))
            case final roots when roots.isNotEmpty)
          folder.id: roots,
  };

  /// When the oldest listing behind this began: every write that ended
  /// before shows in it.
  late final Moment? listedAt = switch ([
    for (final folder in folders)
      if (state.bases[folder.base.id] case Listed(:final listedAt)) listedAt,
  ]) {
    [] => null,
    final all => all.reduce((oldest, at) => at.isBefore(oldest) ? at : oldest),
  };

  /// When what is known of the document at [key] was seen: writes that
  /// ended later are not in it.
  Moment? seenAt(DocumentKey key) => switch (state.bases[key.baseId]) {
    Listed() && final base => base.seenAt(key.path),
    _ => null,
  };

  /// Whether the document at [key] is seen as it is, if it exists: a
  /// folder shows it, its base folder was listed, and no subfolder above
  /// it could not be read. If not, a document missing from [documents]
  /// may still exist.
  bool covers(DocumentKey key) =>
      folders.folderOf(key.baseId, key.path) != null &&
      switch (state.bases[key.baseId]) {
        Listed() && final base => base.sees(key.path),
        _ => false,
      };

  /// What is known of the document at [key]: found in a version, gone,
  /// or unknown where it could not be seen (see [covers]). A document of
  /// a base folder no folder shows any more is gone.
  Observation observe(DocumentKey key) => switch (findNote(key)) {
    _ when !folders.any((folder) => folder.base.id == key.baseId) =>
      const Gone(),
    _ when !covers(key) => const Unknown(),
    final found? => Found(listedVersion(found)),
    null => const Gone(),
  };

  DocumentFolder? _folder(String folderId) =>
      folders.where((folder) => folder.id == folderId).firstOrNull;

  Listed? _listedOf(String folderId) => switch (_folder(folderId)) {
    final folder? => switch (state.bases[folder.base.id]) {
      final Listed base => base,
      _ => null,
    },
    null => null,
  };
}
