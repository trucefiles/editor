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

/// The library's operations on [editor], whose document is laid out by
/// [layout]; only paste is ours ([paste]), e.g. for the touch toolbars.
final class PasteOperations extends CommonEditorOperations {
  PasteOperations(Editor editor, this._paste, {required GlobalKey layout})
    : super(
        editor: editor,
        document: editor.document,
        composer: editor.composer,
        documentLayoutResolver: () => layout.currentState! as DocumentLayout,
      );

  final PasteText _paste;

  /// The selection, as the toolbars show it.
  ValueListenable<DocumentSelection?> get selection =>
      composer.selectionNotifier;

  @override
  void paste() => unawaited(pasteClipboard(_paste));
}
