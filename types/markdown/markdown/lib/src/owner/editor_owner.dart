import 'package:truce_core/truce_core.dart'
    show EditorBook, Machine, MachineOwner, Owner, StartTimer, Version;

import '../edit/change.dart';
import '../view/rows.dart';
import 'editor_contract.dart';
import 'editor_transition.dart';
import 'editor_work.dart';
import 'history/snapshot.dart';
import 'markdown_start.dart';

export 'editor_contract.dart';
export 'markdown_start.dart';

/// The owner of what one open Markdown document's editor shows (see
/// `editor_contract.dart`).
typedef EditorOwner = Owner<EditorInput, EditorState, EditorEvent>;

/// The editor owner's machine.
typedef EditorMachine =
    Machine<EditorMessage, EditorState, EditorWork, EditorEvent, EditorEffect>;

/// The editor owner of a document starting as [start], read as [version]
/// (`null` for a new document); its only effects are the save timers,
/// which [startTimer] starts (a fake clock in tests).
EditorOwner editorOwner(
  MarkdownStart start, {
  required Version? version,
  EditMode mode = EditMode.visual,
  CheckedItems checkedItems = CheckedItems.moveToEnd,
  StartTimer? startTimer,
}) =>
    MachineOwner<
      EditorMessage,
      EditorInput,
      EditorResult,
      EditorState,
      EditorWork,
      EditorEvent,
      EditorEffect
    >(
      editorMachine(
        start,
        version: version,
        mode: mode,
        checkedItems: checkedItems,
      ),
      startTimer: startTimer,
    );

/// The editor machine of a document starting as [start], read as [version]
/// (`null` for a new document).
EditorMachine editorMachine(
  MarkdownStart start, {
  required Version? version,
  EditMode mode = EditMode.visual,
  CheckedItems checkedItems = CheckedItems.moveToEnd,
}) {
  final document = start.document;
  final view = ViewRows(
    document.doc,
    done: checkedItems == CheckedItems.doneSection ? DoneSections() : null,
  );
  final book = EditorBook<Snapshot>(lineage: version, summary: start.summary);
  return Machine(
    state: EditorState(
      content: mode == EditMode.markdown
          ? MarkdownContent(start.text)
          : FormattedContent(view: view, selection: startOf(view)),
      mode: mode,
      checkedItems: checkedItems,
      revision: 0,
      status: book.status,
    ),
    work: EditorWork(origin: document.origin, book: book),
    step: editorStep,
  );
}
