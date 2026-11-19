import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_files/truce_files.dart';

import '../files/files_wiring.dart';
import '../folders/open_folders_wiring.dart';
import 'image_cleanup.dart';

/// The document images of each open folder.
final documentImageStoresProvider =
    Provider<DocumentImageStore Function(FolderId folder)>((ref) {
      final open = ref.watch(openFoldersProvider);
      return (folder) => DocumentImageStore(open.servicesOf(folder));
    });

/// The document images as moving and restoring files need them.
final linkedFilesProvider = Provider<LinkedFiles>((ref) {
  final storeOf = ref.watch(documentImageStoresProvider);
  return StoreLinkedFiles((folder) => storeOf(folder.id));
});

/// The user's cleanup of unused document images.
final imageCleanupProvider = Provider<ImageCleanup>(
  (ref) => ImageCleanup(
    servicesOf: ref.watch(openFoldersProvider).servicesOf,
    draftsOf: ref.watch(draftsProvider).of,
    openFiles: ref.watch(openFilesProvider),
  ),
);
