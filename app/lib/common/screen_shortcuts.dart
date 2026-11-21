import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Runs [bindings] for keys pressed while this screen is on top, wherever
/// the keyboard focus is, even when nothing has it (e.g. rendered text).
/// Outside any screen (above the app's navigator), always.
///
/// [editingBindings] are keys a text field answers itself (e.g. Ctrl+Z,
/// its own undo): they are the screen's only while no text field has the
/// focus, so typing in a field on the screen (e.g. a calendar's name)
/// keeps them.
class ScreenShortcuts extends StatefulWidget {
  const ScreenShortcuts({
    required this.bindings,
    this.editingBindings = const {},
    required this.child,
    super.key,
  });

  final Map<SingleActivator, VoidCallback> bindings;
  final Map<SingleActivator, VoidCallback> editingBindings;
  final Widget child;

  @override
  State<ScreenShortcuts> createState() => _ScreenShortcutsState();
}

class _ScreenShortcutsState extends State<ScreenShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Not while a dialog, menu or other screen is above this one.
  bool _onKey(KeyEvent event) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final active = {
      ...widget.bindings,
      if (!_textFieldHasFocus) ...widget.editingBindings,
    };
    for (final MapEntry(key: activator, value: action) in active.entries) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        action();
        return true;
      }
    }
    return false;
  }

  /// Whether a text field has the keyboard focus.
  static bool get _textFieldHasFocus =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  @override
  Widget build(BuildContext context) => widget.child;
}
