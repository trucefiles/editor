import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart' show markdownType;
import 'package:truce_markdown_images/truce_markdown_images.dart';

import '../file_types/file_types.dart';
import '../files/files_wiring.dart';
import '../folders/open_folders_wiring.dart';
import 'image_cleanup.dart';

/// The document images of each open folder. Typed here: the Markdown
/// services read it, and the folders know the types.
final Provider<DocumentImageStore Function(FolderId folder)>
documentImageStoresProvider = Provider((ref) {
  final open = ref.watch(openFoldersProvider);
  return (folder) => DocumentImageStore(open.servicesOf(folder));
});

/// How files arrive as they move or are restored: Markdown documents
/// take their images along (see [MarkdownArrival]).
final fileArrivalsProvider = Provider<FileArrivals>((ref) {
  final storeOf = ref.watch(documentImageStoresProvider);
  return FileArrivals(ref.watch(fileTypesProvider).detector, {
    markdownType: MarkdownArrival((folder) => storeOf(folder.id)),
  });
});

/// The user's cleanup of unused document images.
final imageCleanupProvider = Provider<ImageCleanup>(
  (ref) => ImageCleanup(
    servicesOf: ref.watch(openFoldersProvider).servicesOf,
    draftsOf: ref.watch(draftsProvider).of,
    openFiles: ref.watch(openFilesProvider),
  ),
);
