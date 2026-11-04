import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

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
  for (final MapEntry(key: keypad, value: key) in keypadStandsFor.entries)
    for (final shift in const [false, true])
      for (final control in const [false, true])
        SingleActivator(
          keypad,
          shift: shift,
          control: control,
          numLock: LockState.unlocked,
        ): ?_intentOf(
          key,
          collapse: !shift,
          control: control,
        ),
};

/// What [key] does in a text field, with Control if [control]; moves the
/// caret if [collapse], else extends the selection.
Intent? _intentOf(
  LogicalKeyboardKey key, {
  required bool collapse,
  required bool control,
}) => switch ((key, control)) {
  (LogicalKeyboardKey.arrowLeft, false) => ExtendSelectionByCharacterIntent(
    forward: false,
    collapseSelection: collapse,
  ),
  (LogicalKeyboardKey.arrowRight, false) => ExtendSelectionByCharacterIntent(
    forward: true,
    collapseSelection: collapse,
  ),
  (LogicalKeyboardKey.arrowLeft, true) =>
    ExtendSelectionToNextWordBoundaryIntent(
      forward: false,
      collapseSelection: collapse,
    ),
  (LogicalKeyboardKey.arrowRight, true) =>
    ExtendSelectionToNextWordBoundaryIntent(
      forward: true,
      collapseSelection: collapse,
    ),
  (LogicalKeyboardKey.arrowUp, false) =>
    ExtendSelectionVerticallyToAdjacentLineIntent(
      forward: false,
      collapseSelection: collapse,
    ),
  (LogicalKeyboardKey.arrowDown, false) =>
    ExtendSelectionVerticallyToAdjacentLineIntent(
      forward: true,
      collapseSelection: collapse,
    ),
  (LogicalKeyboardKey.pageUp, false) =>
    ExtendSelectionVerticallyToAdjacentPageIntent(
      forward: false,
      collapseSelection: collapse,
    ),
  (LogicalKeyboardKey.pageDown, false) =>
    ExtendSelectionVerticallyToAdjacentPageIntent(
      forward: true,
      collapseSelection: collapse,
    ),
  (LogicalKeyboardKey.home, false) => ExtendSelectionToLineBreakIntent(
    forward: false,
    collapseSelection: collapse,
  ),
  (LogicalKeyboardKey.end, false) => ExtendSelectionToLineBreakIntent(
    forward: true,
    collapseSelection: collapse,
  ),
  (LogicalKeyboardKey.home, true) => ExtendSelectionToDocumentBoundaryIntent(
    forward: false,
    collapseSelection: collapse,
  ),
  (LogicalKeyboardKey.end, true) => ExtendSelectionToDocumentBoundaryIntent(
    forward: true,
    collapseSelection: collapse,
  ),
  _ => null,
};
