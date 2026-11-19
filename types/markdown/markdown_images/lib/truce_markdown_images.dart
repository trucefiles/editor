/// The images Markdown documents show, kept by the app in one
/// `document-images` folder at the root of each folder: the name rule,
/// which images a document links (as read), adding an image, taking
/// images along and changing links as a document moves or is restored
/// ([MarkdownArrival]), and the user's cleanup of unused ones.
///
/// Pure Dart, no UI, on `markdown` and `files`; `files` and `core` know
/// nothing of it: the app hands its rule down as the folder's files kept
/// apart, and [MarkdownArrival] in as the Markdown type's `FileArrival`.
library;

export 'src/document_image_store.dart';
export 'src/image_names.dart';
export 'src/markdown_arrival.dart';
export 'src/unused_images.dart';
