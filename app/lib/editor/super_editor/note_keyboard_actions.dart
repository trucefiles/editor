import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../text_format.dart';
import 'key_actions.dart';
import 'keypad_keys.dart';

/// The editor's key handling: the library's defaults for IME input,
/// without its own Markdown-unaware formatting, indenting and Backspace
/// rules. Instead, Backspace at the start and Delete at the end of a node
/// join it with the text next to it, and over a hard line break delete it
/// as one; Shift+Enter breaks the line; Tab and Shift+Tab indent and
/// outdent the item the caret is in (all through [keys]); Ctrl+B, I and
/// K [onFormat] the selection. The keypad's navigation keys work as the
/// keys they stand for.
List<SuperEditorKeyboardAction> noteKeyboardActions({
  required void Function(TextFormat format) onFormat,
  required KeyActions keys,
}) {
  final actions = [
    _backspaceToJoin,
    _deleteToJoin,
    _deleteHardBreak(keys),
    _shiftEnterToBreakLine(keys),
    _formatShortcuts(onFormat),
    _tabToIndent(keys),
    for (final action in defaultImeKeyboardActions)
      if (!_replaced.contains(action)) action,
  ];
  return [keypadKeys(actions), ...actions];
}

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

/// Whether Control, Alt or Meta is held: the key means something else.
bool get _withModifier {
  final keyboard = HardwareKeyboard.instance;
  return keyboard.isControlPressed ||
      keyboard.isAltPressed ||
      keyboard.isMetaPressed;
}

/// The text node the collapsed caret is in, with the caret's offset.
(TextNode, int)? _caret(SuperEditorContext context) {
  final selection = context.composer.selection;
  if (selection == null || !selection.isCollapsed) return null;
  final node = context.document.getNodeById(selection.extent.nodeId);
  final position = selection.extent.nodePosition;
  if (node is! TextNode || position is! TextNodePosition) return null;
  return (node, position.offset);
}

ExecutionInstruction _backspaceToJoin({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (!_isDown(keyEvent) ||
      keyEvent.logicalKey != LogicalKeyboardKey.backspace ||
      _withModifier) {
    return ExecutionInstruction.continueExecution;
  }
  if (_caret(editContext) case (final node, 0)) {
    editContext.editor.execute([DeleteUpstreamAtBeginningOfNodeRequest(node)]);
    return ExecutionInstruction.haltExecution;
  }
  return ExecutionInstruction.continueExecution;
}

ExecutionInstruction _deleteToJoin({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (!_isDown(keyEvent) ||
      keyEvent.logicalKey != LogicalKeyboardKey.delete ||
      _withModifier) {
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

SuperEditorKeyboardAction _tabToIndent(KeyActions keys) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      if (!_isDown(keyEvent) || keyEvent.logicalKey != LogicalKeyboardKey.tab) {
        return ExecutionInstruction.continueExecution;
      }
      final outdent = HardwareKeyboard.instance.isShiftPressed;
      return keys.indentAtCaret(outdent: outdent)
          ? ExecutionInstruction.haltExecution
          : ExecutionInstruction.continueExecution;
    };

SuperEditorKeyboardAction _shiftEnterToBreakLine(KeyActions keys) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      final keyboard = HardwareKeyboard.instance;
      if (!_isDown(keyEvent) ||
          (keyEvent.logicalKey != LogicalKeyboardKey.enter &&
              keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) ||
          !keyboard.isShiftPressed ||
          _withModifier) {
        return ExecutionInstruction.continueExecution;
      }
      keys.lineBreak();
      return ExecutionInstruction.haltExecution;
    };

/// Delete right before a hard line break deletes it as one: its
/// backslash and the line break. (A line break deleted alone takes its
/// backslash along in the note, from any keyboard.)
SuperEditorKeyboardAction _deleteHardBreak(KeyActions keys) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      if (!_isDown(keyEvent) ||
          keyEvent.logicalKey != LogicalKeyboardKey.delete ||
          _withModifier) {
        return ExecutionInstruction.continueExecution;
      }
      final caret = _caret(editContext);
      if (caret == null) return ExecutionInstruction.continueExecution;
      final (node, offset) = caret;
      if (!hardBreakAfter(node.text.toPlainText(), offset)) {
        return ExecutionInstruction.continueExecution;
      }
      keys.replaceText(node.id, offset, offset + 2, '');
      return ExecutionInstruction.haltExecution;
    };
