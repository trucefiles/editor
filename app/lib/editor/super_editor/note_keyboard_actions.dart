import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../text_format.dart';
import 'components/line_actions.dart';

/// The editor's key handling: the library's defaults for IME input,
/// without its own Markdown-unaware formatting, indenting and Backspace
/// rules. Instead, Backspace at the start and Delete at the end of a line
/// join lines (see `joinLines`), Ctrl+B, I and K [onFormat] the selection,
/// and with [lineActions], Tab and Shift+Tab indent and outdent list items.
List<SuperEditorKeyboardAction> noteKeyboardActions({
  required void Function(TextFormat format) onFormat,
  LineActions? lineActions,
}) => [
  _backspaceToJoinLines,
  _deleteToJoinLines,
  _formatShortcuts(onFormat),
  if (lineActions != null) _tabToIndent(lineActions),
  for (final action in defaultImeKeyboardActions)
    if (!_replaced.contains(action)) action,
];

/// Default actions that format, indent or delete in ways that don't fit
/// lines of Markdown.
final _replaced = <SuperEditorKeyboardAction>{
  cmdBToToggleBold,
  cmdIToToggleItalics,
  backspaceToUnIndentListItem,
  backspaceToUnIndentParagraph,
  backspaceToUnIndentTask,
  backspaceToConvertTaskToParagraph,
  backspaceToClearParagraphBlockType,
  tabToIndentTask,
  shiftTabToUnIndentTask,
  tabToIndentParagraph,
  shiftTabToUnIndentParagraph,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  enterToUnIndentParagraph,
  shiftEnterToInsertNewlineInBlock,
};

bool _isDown(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

/// The text node the collapsed caret is in, with the caret's offset.
(TextNode, int)? _caret(SuperEditorContext context) {
  final selection = context.composer.selection;
  if (selection == null || !selection.isCollapsed) return null;
  final node = context.document.getNodeById(selection.extent.nodeId);
  final position = selection.extent.nodePosition;
  if (node is! TextNode || position is! TextNodePosition) return null;
  return (node, position.offset);
}

ExecutionInstruction _backspaceToJoinLines({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (!_isDown(keyEvent) ||
      keyEvent.logicalKey != LogicalKeyboardKey.backspace ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isAltPressed ||
      HardwareKeyboard.instance.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }
  if (_caret(editContext) case (final node, 0)) {
    editContext.editor.execute([DeleteUpstreamAtBeginningOfNodeRequest(node)]);
    return ExecutionInstruction.haltExecution;
  }
  return ExecutionInstruction.continueExecution;
}

ExecutionInstruction _deleteToJoinLines({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (!_isDown(keyEvent) ||
      keyEvent.logicalKey != LogicalKeyboardKey.delete ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isAltPressed ||
      HardwareKeyboard.instance.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }
  final caret = _caret(editContext);
  if (caret == null || caret.$2 != caret.$1.text.length) {
    return ExecutionInstruction.continueExecution;
  }
  final next = editContext.document.getNodeAfterById(caret.$1.id);
  if (next == null) return ExecutionInstruction.haltExecution;
  editContext.editor.execute([
    CombineParagraphsRequest(firstNodeId: caret.$1.id, secondNodeId: next.id),
  ]);
  return ExecutionInstruction.haltExecution;
}

SuperEditorKeyboardAction _formatShortcuts(
  void Function(TextFormat format) onFormat,
) => ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  final keyboard = HardwareKeyboard.instance;
  if (!_isDown(keyEvent) ||
      !(keyboard.isControlPressed || keyboard.isMetaPressed) ||
      keyboard.isShiftPressed ||
      keyboard.isAltPressed) {
    return ExecutionInstruction.continueExecution;
  }
  final format = switch (keyEvent.logicalKey) {
    LogicalKeyboardKey.keyB => TextFormat.bold,
    LogicalKeyboardKey.keyI => TextFormat.italic,
    LogicalKeyboardKey.keyK => TextFormat.link,
    _ => null,
  };
  if (format == null) return ExecutionInstruction.continueExecution;
  onFormat(format);
  return ExecutionInstruction.haltExecution;
};

SuperEditorKeyboardAction _tabToIndent(LineActions actions) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      if (!_isDown(keyEvent) || keyEvent.logicalKey != LogicalKeyboardKey.tab) {
        return ExecutionInstruction.continueExecution;
      }
      final selection = editContext.composer.selection;
      final node = selection == null
          ? null
          : editContext.document.getNodeById(selection.extent.nodeId);
      if (node is! TaskNode && node is! ListItemNode) {
        return ExecutionInstruction.continueExecution;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        actions.outdent(node!.id);
      } else {
        actions.indent(node!.id);
      }
      return ExecutionInstruction.haltExecution;
    };
