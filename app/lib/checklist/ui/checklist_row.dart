import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truce_core/truce_core.dart';

import 'swipe_to_indent.dart';

/// Indent per checklist level.
const _levelIndent = 28.0;

/// Width before the box, where an item's drag handle sits.
const checklistHandleWidth = 24.0;

/// The box of a checklist row, a checkbox or an add icon, in the same
/// space on every row, so their texts line up.
class ChecklistBoxSlot extends StatelessWidget {
  const ChecklistBoxSlot(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: kMinInteractiveDimension,
    child: Center(child: child),
  );
}

/// The look of a checklist row's text field; [hint] for an add row.
InputDecoration checklistFieldDecoration({String? hint}) =>
    InputDecoration(hintText: hint, border: InputBorder.none, isDense: true);

/// One checkbox item: checkbox, inline-editable text and a menu. Swipe
/// right or left to indent or outdent.
class ChecklistItemRow extends StatefulWidget {
  const ChecklistItemRow({
    required this.line,
    required this.depth,
    required this.onToggle,
    required this.onTextChanged,
    required this.onSubmitted,
    required this.onAction,
    required this.focusNode,
    required this.onFocusStep,
    required this.onJoin,
    required this.takeCaret,
    this.dragHandle,
    super.key,
  });

  final MarkdownLine line;
  final int depth;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;

  /// Enter: the next item is created.
  final VoidCallback onSubmitted;
  final ValueChanged<ItemAction> onAction;

  /// Wraps the drag icon so it starts a reorder; `null` if not draggable.
  final Widget Function(Widget icon)? dragHandle;

  /// Focus of the text field; owned by the list, which moves it between
  /// rows.
  final FocusNode focusNode;

  /// Arrow up (−1) or down (+1): the cursor should go to the next row.
  final ValueChanged<int> onFocusStep;

  /// Backspace at the start or Delete at the end of the text, as joining
  /// lines in a text editor.
  final ValueChanged<ItemJoin> onJoin;

  /// Where an action that changed this row wants the cursor, if anywhere;
  /// see `RowFocus.focusLater`.
  final int? Function() takeCaret;

  @override
  State<ChecklistItemRow> createState() => _ChecklistItemRowState();
}

enum ItemAction { indent, outdent, delete }

/// Which row an item joins with.
enum ItemJoin {
  /// Backspace at the start of the text.
  above,

  /// Delete at the end of the text.
  below,
}

class _ChecklistItemRowState extends State<ChecklistItemRow> {
  late final _text = TextEditingController(text: widget.line.text);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
    // Built anew, e.g. as a row above was joined away.
    if (widget.takeCaret() case final caret?) {
      _text.selection = TextSelection.collapsed(offset: caret);
    }
  }

  /// The menu shows only on the row being edited.
  void _onFocusChanged() => setState(() {});

  @override
  void didUpdateWidget(ChecklistItemRow old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    // An action here (a join) changed the text: show it, cursor at the
    // join. Text changed elsewhere (another device, undo): show it unless
    // the user is typing here.
    if (widget.takeCaret() case final caret?) {
      _text.value = TextEditingValue(
        text: widget.line.text,
        selection: TextSelection.collapsed(offset: caret),
      );
    } else if (!widget.focusNode.hasFocus && _text.text != widget.line.text) {
      _text.text = widget.line.text;
    }
  }

  /// Joins on Backspace at the start or Delete at the end of the text;
  /// leaves other keys, and those while composing, to the text field.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final TextEditingValue(:selection, :composing, :text) = _text.value;
    if (!selection.isCollapsed || composing.isValid) {
      return KeyEventResult.ignored;
    }
    final join = switch (event.logicalKey) {
      LogicalKeyboardKey.backspace when selection.baseOffset == 0 =>
        ItemJoin.above,
      LogicalKeyboardKey.delete when selection.baseOffset == text.length =>
        ItemJoin.below,
      _ => null,
    };
    if (join == null) return KeyEventResult.ignored;
    widget.onJoin(join);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SwipeToIndent(
      step: _levelIndent,
      onIndent: () => widget.onAction(ItemAction.indent),
      onOutdent: () => widget.onAction(ItemAction.outdent),
      child: _row(context),
    );
  }

  Widget _row(BuildContext context) {
    final checked = widget.line.isChecked;
    final textStyle = checked
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).disabledColor,
          )
        : null;
    final handle = widget.dragHandle;
    return Padding(
      padding: EdgeInsets.only(left: widget.depth * _levelIndent),
      child: Row(
        children: [
          SizedBox(
            width: checklistHandleWidth,
            child: handle == null
                ? null
                : SwipeToIndent.keepMouseDrags(
                    handle(const Icon(Icons.drag_indicator)),
                  ),
          ),
          ChecklistBoxSlot(
            Checkbox(value: checked, onChanged: (_) => widget.onToggle()),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.tab): () =>
                    widget.onAction(ItemAction.indent),
                const SingleActivator(
                  LogicalKeyboardKey.tab,
                  shift: true,
                ): () =>
                    widget.onAction(ItemAction.outdent),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    widget.onFocusStep(-1),
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    widget.onFocusStep(1),
              },
              child: SwipeToIndent.keepMouseDrags(
                Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _text,
                    focusNode: widget.focusNode,
                    // Long text wraps instead of scrolling sideways, so a
                    // swipe on it indents; Enter still adds the next item.
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    style: textStyle,
                    decoration: checklistFieldDecoration(),
                    onChanged: widget.onTextChanged,
                    // Keeps the cursor here until the next item takes
                    // it, so the keyboard stays open in between.
                    onEditingComplete: () {},
                    onSubmitted: (_) => widget.onSubmitted(),
                  ),
                ),
              ),
            ),
          ),
          // Kept in the tree while hidden: an open menu outlives the focus.
          Visibility(
            visible: widget.focusNode.hasFocus,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: PopupMenuButton<ItemAction>(
              tooltip: 'Item actions',
              onSelected: widget.onAction,
              itemBuilder: (_) => const [
                PopupMenuItem(value: ItemAction.indent, child: Text('Indent')),
                PopupMenuItem(
                  value: ItemAction.outdent,
                  child: Text('Outdent'),
                ),
                PopupMenuItem(value: ItemAction.delete, child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
