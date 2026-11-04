import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import 'own_clipboard.dart';

/// A right click on the super_editor [child] shows the editing menu at
/// the pointer: Cut, Copy, Paste and Select all, run by [operations] as
/// their keys run (paste is ours, one undo step). A click outside the
/// selection first places the caret there, as on any desktop. Like any
/// menu, it closes on a click elsewhere, a key, or typing. Touch keeps its own
/// toolbar (see `TouchControls`).
///
/// Own code, as the library has no menu for a right click.
class EditingMenu extends StatefulWidget {
  const EditingMenu({required this.operations, required this.child, super.key});

  final MenuOperations operations;
  final Widget child;

  @override
  State<EditingMenu> createState() => _EditingMenuState();
}

class _EditingMenuState extends State<EditingMenu> {
  final _menu = ContextMenuController();

  /// Around the editor: Esc passes it on its way up the focus tree. Has
  /// the focus itself while the menu shows and the editor has none.
  final _keys = FocusNode(skipTraversal: true);

  /// The selection watched while the menu shows.
  Listenable? _watched;

  @override
  void dispose() {
    _close();
    _keys.dispose();
    super.dispose();
  }

  void _close() {
    if (!_menu.isShown) return;
    _menu.remove();
    HardwareKeyboard.instance.removeHandler(_keyCloses);
    _watched?.removeListener(_close);
    _watched = null;
    if (_keys.hasPrimaryFocus) _keys.unfocus();
  }

  /// A key closes the menu and still does what it does; Esc is left to
  /// [_escCloses].
  bool _keyCloses(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey != LogicalKeyboardKey.escape) {
      _close();
    }
    return false;
  }

  /// Esc closes the menu and does nothing else, so it doesn't reach the
  /// screen (which it would leave).
  KeyEventResult _escCloses(FocusNode _, KeyEvent event) {
    if (!_menu.isShown ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _close();
    return KeyEventResult.handled;
  }

  void _open(Offset at) {
    final operations = widget.operations..placeCaretForMenu(at);
    final selection = operations.selection.value;
    final selected = selection != null && !selection.isCollapsed;
    ContextMenuButtonItem item(ContextMenuButtonType type, VoidCallback run) =>
        ContextMenuButtonItem(
          type: type,
          onPressed: () {
            _close();
            run();
          },
        );
    _menu.show(
      context: context,
      contextMenuBuilder: (context) => TapRegion(
        groupId: _menu,
        child: AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: at),
          buttonItems: [
            if (selected) ...[
              item(ContextMenuButtonType.cut, operations.cut),
              item(ContextMenuButtonType.copy, operations.copy),
            ],
            if (selection != null)
              item(ContextMenuButtonType.paste, operations.paste),
            item(ContextMenuButtonType.selectAll, operations.selectAll),
          ],
        ),
      ),
    );
    HardwareKeyboard.instance.addHandler(_keyCloses);
    _watched = operations.selection..addListener(_close);
    if (!_keys.hasFocus) _keys.requestFocus();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    groupId: _menu,
    onTapOutside: (_) => _close(),
    child: Focus(
      focusNode: _keys,
      onKeyEvent: _escCloses,
      child: Listener(
        onPointerDown: (_) => _close(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: (details) => _open(details.globalPosition),
          child: widget.child,
        ),
      ),
    ),
  );
}
