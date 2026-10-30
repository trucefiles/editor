/// Markdown documents for Truce: read into a doc tree, edited by
/// commands in Visual edit, and printed back block-exact (blocks the user
/// didn't touch keep their bytes).
///
/// Pure Dart, no UI; `core` knows nothing of it. What the app uses is
/// exported here: the editor's owner ([EditorOwner]), what its inputs
/// name and its state shows, and the Markdown tree Markdown edit
/// highlights by.
library;

export 'src/doc/doc_nodes.dart';
export 'src/doc/doc_tree.dart' show DocTree;
export 'src/document_tree.dart' show DocumentTree;
export 'src/edit/clipboard_lines.dart';
export 'src/edit/commands/command.dart';
export 'src/edit/keys/key_map.dart';
export 'src/edit/selection.dart';
export 'src/edit/typing_style.dart';
export 'src/highlight/highlights.dart';
export 'src/owner/editor_owner.dart';
export 'src/read/front_matter.dart' show textAfterFrontMatter;
export 'src/summary/document_summary.dart';
export 'src/support/markdown_support.dart';
export 'src/tree/blocks.dart';
export 'src/tree/inlines.dart' show HtmlInline, ImageInline, Inline;
export 'src/view/rows.dart';
export 'src/visible/formatting.dart';
export 'src/visible/visible_text.dart';
