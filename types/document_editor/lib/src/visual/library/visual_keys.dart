import 'dart:async';

import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditKey;

import '../../library/keypad_keys.dart';
import '../../library/own_paste.dart';
import '../../library/rich_text_keys.dart';
import 'visual_adapter.dart';

/// Visual edit's key handling: the keys that edit go to the owner as what
/// they are ([EditKey]), while no input method composes (so dead keys
/// and input methods keep their keys); copy keeps what it copied for a
/// paste here, and Ctrl+V pastes as one edit. Caret and selection keys
/// are the library's; in an open raw block, its text is edited as plain
/// text by the library's keys. The keypad's navigation keys work as the
/// keys they stand for.
List<SuperEditorKeyboardAction> visualKeyboardActions(VisualAdapter adapter) {
  final actions = [
    _copy(adapter),
    pasteKey(adapter.paste),
    _editKeys(adapter),
    _tabInRaw(adapter),
    for (final action in defaultImeKeyboardActions)
      if (!richTextKeys.contains(action)) action,
  ];
  return [keypadKeys(actions), ...actions];
}

bool _isDown(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

/// The [EditKey] [event] is, by its key and the modifiers held.
EditKey? _editKeyOf(KeyEvent event) {
  final keyboard = HardwareKeyboard.instance;
  final control = keyboard.isControlPressed || keyboard.isMetaPressed;
  final shift = keyboard.isShiftPressed;
  if (keyboard.isAltPressed) return null;
  final key = event.logicalKey;
  return switch ((control, shift)) {
    (false, _)
        when key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter =>
      shift ? EditKey.shiftEnter : EditKey.enter,
    (false, false) when key == LogicalKeyboardKey.backspace =>
      EditKey.backspace,
    (false, false) when key == LogicalKeyboardKey.delete => EditKey.delete,
    (false, _) when key == LogicalKeyboardKey.tab =>
      shift ? EditKey.shiftTab : EditKey.tab,
    (true, false) => _controlKeys[key],
    (true, true) => _controlShiftKeys[key],
    _ => null,
  };
}

final _controlKeys = {
  LogicalKeyboardKey.keyB: EditKey.bold,
  LogicalKeyboardKey.keyI: EditKey.italic,
  LogicalKeyboardKey.keyK: EditKey.link,
};

final _controlShiftKeys = {
  LogicalKeyboardKey.digit7: EditKey.numbered,
  LogicalKeyboardKey.digit8: EditKey.bullet,
  LogicalKeyboardKey.digit9: EditKey.checklist,
};

SuperEditorKeyboardAction _editKeys(VisualAdapter adapter) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      if (!_isDown(keyEvent) || adapter.composing || adapter.inRaw) {
        return ExecutionInstruction.continueExecution;
      }
      final key = _editKeyOf(keyEvent);
      if (key == null) return ExecutionInstruction.continueExecution;
      adapter.press(key);
      return ExecutionInstruction.haltExecution;
    };

/// Tab in an open raw block types a tab.
SuperEditorKeyboardAction _tabInRaw(VisualAdapter adapter) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      if (!_isDown(keyEvent) ||
          !adapter.inRaw ||
          keyEvent.logicalKey != LogicalKeyboardKey.tab) {
        return ExecutionInstruction.continueExecution;
      }
      editContext.editor.execute([InsertPlainTextAtCaretRequest('\t')]);
      return ExecutionInstruction.haltExecution;
    };

/// Ctrl+C and Ctrl+X: the selection to the clipboard as plain text,
/// remembered with its styles for a paste here; Ctrl+X then removes it.
SuperEditorKeyboardAction _copy(VisualAdapter adapter) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      final keyboard = HardwareKeyboard.instance;
      final key = keyEvent.logicalKey;
      if (!_isDown(keyEvent) ||
          !(keyboard.isControlPressed || keyboard.isMetaPressed) ||
          keyboard.isShiftPressed ||
          adapter.inRaw ||
          (key != LogicalKeyboardKey.keyC && key != LogicalKeyboardKey.keyX)) {
        return ExecutionInstruction.continueExecution;
      }
      final text = adapter.copySelection();
      if (text == null) return ExecutionInstruction.haltExecution;
      unawaited(Clipboard.setData(ClipboardData(text: text)));
      if (key == LogicalKeyboardKey.keyX) adapter.deleteSelection();
      return ExecutionInstruction.haltExecution;
    };
