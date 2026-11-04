import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'own_clipboard.dart';

/// A right click on the super_editor [child] shows the editing menu at
/// the pointer: Cut, Copy, Paste and Select all, run by [operations] as
/// their keys run (paste is ours, one undo step). A click outside the
/// selection first places the caret there, as on any desktop. Touch keeps
/// its own toolbar (see `TouchControls`).
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

  @override
  void dispose() {
    _menu.remove();
    super.dispose();
  }

  void _open(Offset at) {
    final operations = widget.operations..placeCaretForMenu(at);
    final selection = operations.selection.value;
    final selected = selection != null && !selection.isCollapsed;
    ContextMenuButtonItem item(ContextMenuButtonType type, VoidCallback run) =>
        ContextMenuButtonItem(
          type: type,
          onPressed: () {
            _menu.remove();
            run();
          },
        );
    _menu.show(
      context: context,
      contextMenuBuilder: (context) => AdaptiveTextSelectionToolbar.buttonItems(
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
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onSecondaryTapUp: (details) => _open(details.globalPosition),
    child: widget.child,
  );
}
