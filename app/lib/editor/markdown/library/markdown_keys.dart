import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../library/keypad_keys.dart';
import '../../library/rich_text_keys.dart';

/// Markdown edit's key handling: the library's keys for plain text, and
/// Tab types a tab. The keypad's navigation keys work as the keys they
/// stand for.
List<SuperEditorKeyboardAction> markdownKeyboardActions() {
  final actions = [
    _tabTypesTab,
    for (final action in defaultImeKeyboardActions)
      if (!richTextKeys.contains(action)) action,
  ];
  return [keypadKeys(actions), ...actions];
}

ExecutionInstruction _tabTypesTab({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  final keyboard = HardwareKeyboard.instance;
  final selection = editContext.composer.selection;
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent ||
      keyEvent.logicalKey != LogicalKeyboardKey.tab ||
      keyboard.isShiftPressed ||
      keyboard.isControlPressed ||
      keyboard.isAltPressed ||
      keyboard.isMetaPressed ||
      selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  editContext.editor.execute([
    if (!selection.isCollapsed)
      const DeleteSelectionRequest(TextAffinity.downstream),
    const InsertPlainTextAtCaretRequest('\t'),
  ]);
  return ExecutionInstruction.haltExecution;
}
