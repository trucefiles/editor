import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Runs [bindings] for keys pressed while this screen is on top, wherever
/// the keyboard focus is, even when nothing has it (e.g. rendered text).
class ScreenShortcuts extends StatefulWidget {
  const ScreenShortcuts({
    required this.bindings,
    required this.child,
    super.key,
  });

  final Map<SingleActivator, VoidCallback> bindings;
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
    for (final MapEntry(key: activator, value: action)
        in widget.bindings.entries) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        action();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
