/// Markdown documents for Truce: read into a CommonMark + GFM block
/// tree, edited by commands in Visual edit, and written back byte-exact.
///
/// Pure Dart, no UI; `core` knows nothing of it. What the app uses is
/// exported here: the editor's owner ([EditorOwner]) and what its inputs
/// name.
library;

export 'src/document_tree.dart' show DocumentTree;
export 'src/edit/clipboard/clipboard_lines.dart';
export 'src/edit/commands/command.dart';
export 'src/edit/keys/key_map.dart';
export 'src/edit/shown/rows.dart';
export 'src/edit/shown/selection.dart';
export 'src/edit/shown/shown_document.dart' show ShownDocument;
export 'src/edit/shown/slot.dart';
export 'src/edit/shown/typing_style.dart';
export 'src/lines/line.dart';
export 'src/lines/line_change.dart';
export 'src/owner/editor_owner.dart';
export 'src/tree/blocks.dart';
export 'src/visible/formatting.dart' show Formatting, TextFormat;
export 'src/visible/visible_text.dart' show VisibleText;
