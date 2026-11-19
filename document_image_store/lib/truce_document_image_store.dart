/// The images documents show, kept by the app in one `document-images`
/// folder at the root of each folder: the name rule, adding an image,
/// copying images along when a document moves to another folder,
/// bringing removed ones back before a restore, and the user's cleanup
/// of unused ones.
///
/// Pure Dart, no UI, on `files`; `files` and `core` know nothing of it:
/// the app hands its rule down as the folder's files kept apart, and its
/// [StoreLinkedFiles] up as `files`' `LinkedFiles`.
library;

export 'src/document_image_store.dart';
export 'src/image_names.dart';
export 'src/store_linked_files.dart';
export 'src/unused_images.dart';
