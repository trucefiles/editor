import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

/// The user's cleanup of a folder's unused document images: open
/// documents of the folder keep their edits first, so every link is in
/// a file or a draft before any is looked for (see [UnusedImages]).
class ImageCleanup {
  const ImageCleanup({
    required this._servicesOf,
    required this._storeOf,
    required this._draftsOf,
    required this._oldDraftsOf,
    required this._openEdits,
    required this._isDocument,
    this._now,
  });

  final FolderServices Function(FolderId folder) _servicesOf;
  final DocumentImageStore Function(FolderId folder) _storeOf;
  final FileDrafts Function(FolderId folder) _draftsOf;
  final OldDrafts Function(FolderId folder) _oldDraftsOf;
  final OpenEdits _openEdits;

  /// Whether a file is a Markdown document.
  final bool Function(RelPath path) _isDocument;
  final DateTime Function()? _now;

  /// The unused images of [folder], to remove with [remove].
  Future<Result<List<FileEntry>, CleanupRefused>> find(FolderId folder) async {
    await _openEdits.secureIn(folder, SecureReason.hide);
    return _unused(folder).find();
  }

  /// Removes [images], as [find] gave them for [folder]: how many went.
  Future<int> remove(FolderId folder, List<FileEntry> images) =>
      _unused(folder).remove(images);

  UnusedImages _unused(FolderId folder) {
    return UnusedImages(
      _storeOf(folder),
      _servicesOf(folder),
      drafts: _draftsOf(folder),
      oldDrafts: _oldDraftsOf(folder),
      isDocument: _isDocument,
      now: _now,
    );
  }
}
