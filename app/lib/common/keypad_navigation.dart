import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes the keypad's navigation keys (NumLock off) edit text like the keys
/// they stand for, with Shift and Control.
///
/// Flutter's Linux defaults move a line on keypad Home and End and ignore
/// Shift. Place below the app's default shortcuts so these win.
class KeypadNavigation extends StatelessWidget {
  const KeypadNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Shortcuts(shortcuts: _shortcuts, child: child);
}

final Map<ShortcutActivator, Intent> _shortcuts = {
  for (final shift in const [false, true]) ...{
    _keypad(
      LogicalKeyboardKey.numpad4,
      shift: shift,
    ): ExtendSelectionByCharacterIntent(
      forward: false,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad6,
      shift: shift,
    ): ExtendSelectionByCharacterIntent(
      forward: true,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad8,
      shift: shift,
    ): ExtendSelectionVerticallyToAdjacentLineIntent(
      forward: false,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad2,
      shift: shift,
    ): ExtendSelectionVerticallyToAdjacentLineIntent(
      forward: true,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad9,
      shift: shift,
    ): ExtendSelectionVerticallyToAdjacentPageIntent(
      forward: false,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad3,
      shift: shift,
    ): ExtendSelectionVerticallyToAdjacentPageIntent(
      forward: true,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad7,
      shift: shift,
    ): ExtendSelectionToLineBreakIntent(
      forward: false,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad1,
      shift: shift,
    ): ExtendSelectionToLineBreakIntent(
      forward: true,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad4,
      shift: shift,
      control: true,
    ): ExtendSelectionToNextWordBoundaryIntent(
      forward: false,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad6,
      shift: shift,
      control: true,
    ): ExtendSelectionToNextWordBoundaryIntent(
      forward: true,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad7,
      shift: shift,
      control: true,
    ): ExtendSelectionToDocumentBoundaryIntent(
      forward: false,
      collapseSelection: !shift,
    ),
    _keypad(
      LogicalKeyboardKey.numpad1,
      shift: shift,
      control: true,
    ): ExtendSelectionToDocumentBoundaryIntent(
      forward: true,
      collapseSelection: !shift,
    ),
  },
};

SingleActivator _keypad(
  LogicalKeyboardKey key, {
  required bool shift,
  bool control = false,
}) => SingleActivator(
  key,
  shift: shift,
  control: control,
  numLock: LockState.unlocked,
);
