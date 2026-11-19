import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

/// The user's cleanup of a folder's unused document images: open
/// documents of the folder keep their edits first, so every link is in
/// a file or a draft before any is looked for (see [UnusedImages]).
class ImageCleanup {
  const ImageCleanup({
    required this._servicesOf,
    required this._draftsOf,
    required this._openFiles,
  });

  final FolderServices Function(FolderId folder) _servicesOf;
  final FileDrafts Function(FolderId folder) _draftsOf;
  final OpenFiles _openFiles;

  /// The unused images of [folder], to remove with [remove].
  Future<Result<List<FileEntry>, CleanupRefused>> find(FolderId folder) async {
    await _openFiles.secureIn(folder, SecureReason.hide);
    return _unused(folder).find();
  }

  /// Removes [images], as [find] gave them for [folder]: how many went.
  Future<int> remove(FolderId folder, List<FileEntry> images) =>
      _unused(folder).remove(images);

  UnusedImages _unused(FolderId folder) {
    final services = _servicesOf(folder);
    return UnusedImages(
      DocumentImageStore(services),
      services,
      drafts: _draftsOf(folder).texts,
    );
  }
}
