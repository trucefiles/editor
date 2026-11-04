import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// Puts [text], pasted, in place of the selection, as one undo step.
typedef PasteText = void Function(String text);

/// Pastes the clipboard's text with [paste], once read; an empty
/// clipboard pastes nothing.
///
/// Own code, as the library's paste removes the selection first and
/// pastes later, once the clipboard is read: two edits, so two undo
/// steps. Ours pastes once the clipboard is read, over the selection as
/// it is then, in one edit.
Future<void> pasteClipboard(PasteText paste) async {
  final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  if (text != null && text.isNotEmpty) paste(text);
}

/// [text] pasted over the selection, as one edit: what an editor's
/// [PasteText] asks of its library editor.
final class PasteRequest implements EditRequest {
  const PasteRequest(this.text);

  final String text;
}

/// The library's requests that paste plain [text] over [selection]: the
/// selected text removed, then [text] at the caret.
List<EditRequest> plainPasteRequests(
  String text,
  DocumentSelection? selection,
) => [
  if (selection?.isCollapsed == false)
    const DeleteSelectionRequest(TextAffinity.downstream),
  InsertPlainTextAtCaretRequest(text),
];

/// An editor's own copy: the selection as the clipboard's [text]
/// (`null` with nothing selected), and how to [remove] it for a cut.
typedef OwnCopy = ({String? Function() text, VoidCallback remove});

/// Copies the selection with [copy]; a [cut] then removes it.
void copySelection(OwnCopy copy, {required bool cut}) {
  final text = copy.text();
  if (text == null) return;
  unawaited(Clipboard.setData(ClipboardData(text: text)));
  if (cut) copy.remove();
}

/// Ctrl+V (Cmd+V) pastes with [paste].
SuperEditorKeyboardAction pasteKey(PasteText paste) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent ||
          !keyEvent.isPrimaryShortcutKeyPressed ||
          keyEvent.logicalKey != LogicalKeyboardKey.keyV ||
          editContext.composer.selection == null) {
        return ExecutionInstruction.continueExecution;
      }
      unawaited(pasteClipboard(paste));
      return ExecutionInstruction.haltExecution;
    };

/// What the editing menus (the touch toolbars, the right-click menu) run
/// on [editor], whose document is laid out by [layout]: the library's
/// operations, but paste is ours ([paste]), and copy and cut are ours too
/// where the editor has its own [copy].
final class MenuOperations extends CommonEditorOperations {
  MenuOperations(
    Editor editor,
    this._paste, {
    required GlobalKey layout,
    this._copy,
  }) : super(
         editor: editor,
         document: editor.document,
         composer: editor.composer,
         documentLayoutResolver: () => layout.currentState! as DocumentLayout,
       );

  final PasteText _paste;
  final OwnCopy? _copy;

  /// The selection, as the toolbars show it.
  ValueListenable<DocumentSelection?> get selection =>
      composer.selectionNotifier;

  /// Where a right click at [at] (global) puts the caret: there, unless
  /// [at] is in the selection, which the menu then acts on.
  void placeCaretForMenu(Offset at) {
    final layout = documentLayoutResolver();
    final position = layout.getDocumentPositionNearestToOffset(
      layout.getDocumentOffsetFromAncestorOffset(at),
    );
    final selection = composer.selection;
    final inSelection =
        position != null &&
        selection != null &&
        !selection.isCollapsed &&
        document.doesSelectionContainPosition(selection, position);
    if (position != null && !inSelection) insertCaretAtPosition(position);
  }

  @override
  void paste() => unawaited(pasteClipboard(_paste));

  @override
  void copy() => switch (_copy) {
    final own? => copySelection(own, cut: false),
    null => super.copy(),
  };

  @override
  void cut() => switch (_copy) {
    final own? => copySelection(own, cut: true),
    null => super.cut(),
  };
}
