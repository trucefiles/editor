import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// Makes the keypad's navigation keys (NumLock off) move the caret like
/// the keys they stand for, with Shift and Control: runs [actions] on the
/// key they stand for. The library knows only the main keys, and the app's
/// own keypad shortcuts reach text fields only.
SuperEditorKeyboardAction keypadKeys(List<SuperEditorKeyboardAction> actions) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      final standsFor = _standsFor[keyEvent.logicalKey];
      if (standsFor == null ||
          HardwareKeyboard.instance.lockModesEnabled.contains(
            KeyboardLockMode.numLock,
          )) {
        return ExecutionInstruction.continueExecution;
      }
      final translated = _as(keyEvent, standsFor);
      for (final action in actions) {
        final result = action(editContext: editContext, keyEvent: translated);
        if (result != ExecutionInstruction.continueExecution) return result;
      }
      return ExecutionInstruction.haltExecution;
    };

final _standsFor = {
  LogicalKeyboardKey.numpad4: LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.numpad6: LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.numpad8: LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.numpad2: LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.numpad7: LogicalKeyboardKey.home,
  LogicalKeyboardKey.numpad1: LogicalKeyboardKey.end,
  LogicalKeyboardKey.numpad9: LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.numpad3: LogicalKeyboardKey.pageDown,
};

KeyEvent _as(KeyEvent event, LogicalKeyboardKey key) => switch (event) {
  KeyDownEvent() => KeyDownEvent(
    physicalKey: event.physicalKey,
    logicalKey: key,
    timeStamp: event.timeStamp,
  ),
  KeyRepeatEvent() => KeyRepeatEvent(
    physicalKey: event.physicalKey,
    logicalKey: key,
    timeStamp: event.timeStamp,
  ),
  _ => KeyUpEvent(
    physicalKey: event.physicalKey,
    logicalKey: key,
    timeStamp: event.timeStamp,
  ),
};
