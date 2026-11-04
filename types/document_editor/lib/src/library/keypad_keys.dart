import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

/// Makes the keypad's navigation keys (NumLock off) move the caret like
/// the keys they stand for, with Shift and Control: runs [actions] on the
/// key they stand for. The library knows only the main keys, and the app's
/// own keypad shortcuts reach text fields only.
SuperEditorKeyboardAction keypadKeys(List<SuperEditorKeyboardAction> actions) =>
    ({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
      final standsFor = keypadStandsFor[keyEvent.logicalKey];
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
