import 'package:truce_core/truce_core.dart'
    show Owner, TransitionOwner, Version;

import '../document_tree.dart';
import '../edit/shown/rows.dart';
import '../edit/shown/shown_document.dart';
import 'editor_contract.dart';
import 'editor_state.dart';
import 'editor_transition.dart';

export 'editor_contract.dart';
export 'editor_state.dart' show EditorState, Holds, RawRegion;

/// The owner of what one open Markdown document's editor shows (see
/// `editor_contract.dart`).
typedef EditorOwner = Owner<EditorInput, EditorState, EditorOutput>;

/// The editor owner of a document holding [text], read as [version]
/// (`null` for a new document).
EditorOwner editorOwner(
  String text, {
  required Version? version,
  EditMode mode = EditMode.visual,
  CheckedItems checkedItems = CheckedItems.moveToEnd,
}) {
  final document = ShownDocument(
    DocumentTree.read(text),
    done: checkedItems == CheckedItems.doneSection ? DoneSections() : null,
  );
  final state = EditorState(
    document: document,
    selection: document.firstCaret,
    lineage: version,
    mode: mode,
    checkedItems: checkedItems,
  );
  return TransitionOwner(state, editorStep);
}
