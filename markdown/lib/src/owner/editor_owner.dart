import 'package:truce_core/truce_core.dart'
    show Owner, TransitionOwner, Version;

import '../edit/change.dart';
import '../view/rows.dart';
import 'editor_contract.dart';
import 'editor_transition.dart';
import 'editor_work.dart';
import 'reload.dart';

export 'editor_contract.dart';
export 'save_clock.dart' show SaveTimer;

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
  final document = loaded(text);
  final view = ViewRows(
    document.doc,
    done: checkedItems == CheckedItems.doneSection ? DoneSections() : null,
  );
  return TransitionOwner(
    EditorState(
      content: mode == EditMode.markdown
          ? MarkdownContent(text)
          : FormattedContent(view: view, selection: startOf(view)),
      mode: mode,
      checkedItems: checkedItems,
      revision: 0,
      unsent: false,
    ),
    EditorWork(origin: document.origin, lineage: version),
    editorStep,
  );
}
