import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';
import '../sync_tool/folder_services.dart';
import 'document.dart';

/// Reads the documents of one folder from its scanned files. Keeps the last
/// documents, so only files with a new version are read again.
///
/// Files that are not valid UTF-8 are left out: they cannot be edited
/// without damaging them. A document that can't be read as text any more
/// (e.g. mid-rewrite, briefly no access) keeps its last version while the
/// file exists, so it doesn't look deleted; saving to it then fails its
/// change check instead of overwriting anything. Such documents, and files
/// that vanished after the scan, are [DocumentLoad.unread]: the load does not
/// know their current version.
///
/// A new version with the same text never moves a document's time back: some
/// file systems (e.g. Android's shared storage) report a stale file time
/// right after a write and the real one a moment later, which would make
/// the document jump in the newest-first order and back.
final class DocumentLoader {
  DocumentLoader(this._services);

  final FolderServices _services;
  Map<RelPath, Document> _last = {};

  /// The documents in [files], as listed by the scan of [folder]. [folder] is
  /// passed on every load: the user may rename or recolor it meanwhile.
  Future<DocumentLoad> load(
    DocumentFolder folder,
    List<FileEntry> files,
  ) async {
    final next = <RelPath, Document>{};
    final unread = <RelPath>{};
    for (final entry in files) {
      final (:document, :read) = await _documentFor(folder, entry);
      if (document != null) next[entry.path] = document.inFolder(folder);
      if (!read) unread.add(entry.path);
    }
    _last = next;
    return (documents: next.values.toList(), unread: unread);
  }

  /// The last document if unchanged, else a fresh read; the last document if that
  /// fails while the file still exists; `null` if the file vanished, or is
  /// not text and was never read as text. [read]: whether the document is the
  /// listed version or a newer one, not a stand-in.
  Future<({Document? document, bool read})> _documentFor(
    DocumentFolder folder,
    FileEntry entry,
  ) async {
    final last = _last[entry.path];
    if (last != null && last.version == entry.version) {
      return (document: last, read: true);
    }
    switch (await _services.store.read(entry.path)) {
      case Ok(value: final content):
        return switch (TextFile.decode(content.bytes)) {
          final file? => (
            document: Document(
              folder: folder,
              path: entry.path,
              file: file,
              version: content.version,
              modified: _modified(content.modified, file, last),
            ),
            read: true,
          ),
          null => (document: last, read: false),
        };
      case Err(error: StoreError.notFound):
        return (document: null, read: false);
      case Err():
        return (document: last, read: false);
    }
  }

  /// [read], or [last]'s time if [file] holds [last]'s text and [read] is
  /// older: a restamp, not a change.
  static DateTime _modified(DateTime read, TextFile file, Document? last) =>
      last != null &&
          last.file.text == file.text &&
          read.isBefore(last.modified)
      ? last.modified
      : read;
}

/// What [DocumentLoader.load] found: the documents to show, and the listed files
/// whose current version could not be read.
typedef DocumentLoad = ({List<Document> documents, Set<RelPath> unread});
