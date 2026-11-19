import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show markdownType;
import 'package:truce_markdown_images/truce_markdown_images.dart';

import '../file_types/file_types.dart';
import '../files/files_wiring.dart';
import '../folders/open_folders_wiring.dart';
import 'image_cleanup.dart';

/// Which files of a folder the app keeps apart from the documents: the
/// document images' folder.
final keptApartProvider = Provider<bool Function(RelPath path)>(
  (_) => ImageNames.isKept,
);

/// The document images of each open folder.
final documentImageStoresProvider =
    Provider<DocumentImageStore Function(FolderId folder)>((ref) {
      final open = ref.watch(openFoldersProvider);
      return (folder) => DocumentImageStore(open.servicesOf(folder));
    });

/// How a Markdown document arrives as it moves or is restored: its
/// images go along (see [MarkdownArrival]).
final markdownArrivalProvider = Provider<MarkdownArrival>(
  (ref) => MarkdownArrival(ref.watch(documentImageStoresProvider)),
);

/// The user's cleanup of unused document images.
final imageCleanupProvider = Provider<ImageCleanup>((ref) {
  final detector = ref.watch(fileTypeDetectorProvider);
  return ImageCleanup(
    servicesOf: ref.watch(openFoldersProvider).servicesOf,
    storeOf: ref.watch(documentImageStoresProvider),
    draftsOf: ref.watch(draftsProvider).of,
    openFiles: ref.watch(openFilesProvider),
    isDocument: (path) => detector.detect(path) == markdownType,
  );
});
