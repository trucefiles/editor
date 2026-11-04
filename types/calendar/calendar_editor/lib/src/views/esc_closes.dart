import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// While [open] holds something (e.g. kalender's "+N more" day popup),
/// Esc closes it with [close] and goes no further, so it doesn't leave
/// the page. Meanwhile it takes the keyboard focus if nothing in [child]
/// has it, so Esc reaches it, and gives it back once closed.
class EscCloses extends StatefulWidget {
  const EscCloses({
    required this.open,
    required this.close,
    required this.child,
    super.key,
  });

  final ValueListenable<Object?> open;
  final VoidCallback close;
  final Widget child;

  @override
  State<EscCloses> createState() => _EscClosesState();
}

class _EscClosesState extends State<EscCloses> {
  final _keys = FocusNode(skipTraversal: true);

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_followOpen);
  }

  @override
  void dispose() {
    widget.open.removeListener(_followOpen);
    _keys.dispose();
    super.dispose();
  }

  void _followOpen() => switch ((widget.open.value, _keys.hasFocus)) {
    (_?, false) => _keys.requestFocus(),
    (null, _) when _keys.hasPrimaryFocus => _keys.unfocus(),
    _ => null,
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        widget.open.value == null) {
      return KeyEventResult.ignored;
    }
    widget.close();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _keys, onKeyEvent: _onKey, child: widget.child);
}
