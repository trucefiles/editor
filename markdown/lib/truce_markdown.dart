/// Markdown documents for Truce: read into a CommonMark + GFM block
/// tree, edited by commands in Visual edit, and written back byte-exact.
///
/// Pure Dart, no UI; `core` knows nothing of it. What the app uses is
/// exported here; the editor's owner joins it in a later step.
library;

export 'src/document_tree.dart' show DocumentTree;
export 'src/edit/commands/command.dart';
export 'src/edit/keys/key_map.dart';
export 'src/edit/shown/selection.dart';
export 'src/edit/shown/shown_document.dart' show ShownDocument;
export 'src/edit/shown/slot.dart';
export 'src/edit/shown/typing_style.dart';
