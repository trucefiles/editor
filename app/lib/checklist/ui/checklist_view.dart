import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truce_core/truce_core.dart';

import '../checklist_editor.dart';
import 'checklist_blocks.dart';
import 'checklist_row.dart';
import 'checklist_text_block.dart';
import 'checklist_undo_hint.dart';
import 'row_focus.dart';

/// Keep-like view of a checklist: open items to drag and edit, add rows
/// above and below them, and checked items in a collapsible "Done"
/// section.
class ChecklistView extends StatefulWidget {
  const ChecklistView(
    this.editor, {
    this.separateDone = true,
    this.checkedToEnd = false,
    super.key,
  });

  final ChecklistEditor editor;

  /// Whether checked items show apart, in the "Done" section. View only:
  /// the file order never changes.
  final bool separateDone;

  /// Whether checking an item moves it to the end of the list, and
  /// unchecking back below the open items.
  final bool checkedToEnd;

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  /// Row keys of the add fields in [_focus].
  static const _addTopKey = 'add top';
  static const _addRowKey = 'add';

  final _newTopItem = TextEditingController();
  final _newItem = TextEditingController();
  final _focus = RowFocus();

  /// Items started from an add row, by its field, while the cursor is
  /// still there.
  final _started = <TextEditingController, int>{};
  bool _doneExpanded = true;

  ChecklistEditor get _editor => widget.editor;

  @override
  void dispose() {
    _newTopItem.dispose();
    _newItem.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Typing in an add row starts a new item right away with [add] and
  /// moves the cursor into it, so typed text never lives only in [field]:
  /// it is in the note and saved like any other edit. Keys typed before
  /// the cursor gets there go on into that item. [field] keeps its text
  /// until the cursor leaves it, as clearing it while typing there may
  /// drop keys (see [_endItem]).
  void _startItem(
    TextEditingController field,
    int Function(String text) add,
    String typed,
  ) {
    final text = typed.trimLeft();
    if (_started[field] case final id?) {
      _editor.setText(id, text);
      return;
    }
    if (text.isEmpty) return;
    final id = add(text);
    _started[field] = id;
    _focus.focusLater(id);
  }

  /// The cursor left [field]: its text is in the item it started.
  void _endItem(TextEditingController field) {
    if (_started.remove(field) != null) field.clear();
  }

  void _onAction(MarkdownLine line, ItemAction action) {
    switch (action) {
      case ItemAction.indent:
        _editor.indent(line.id, hidden: _hiddenFrom(line));
      case ItemAction.outdent:
        _editor.outdent(line.id);
      case ItemAction.delete:
        _offerUndo('Item deleted', _editor.remove(line.id));
    }
  }

  /// Lines not shown in [line]'s section. With a "Done" section, open and
  /// done items are shown apart, so only items of the same section are
  /// "above" [line] on screen.
  Set<int> _hiddenFrom(MarkdownLine line) {
    if (!widget.separateDone) return const {};
    final list = _editor.list;
    final done = list.doneIds;
    if (!done.contains(line.id)) return done;
    return {
      for (final other in list.lines)
        if (!done.contains(other.id)) other.id,
    };
  }

  void _offerUndo(String message, ChecklistUndo undo) => showChecklistUndoHint(
    ScaffoldMessenger.of(context),
    _editor,
    message,
    undo,
  );

  /// Joins [line] with the item shown next to it in [section] (open or
  /// done blocks), as joining lines in a text editor: Backspace appends
  /// the item to the one above; Delete appends the one below to it, or
  /// drops the item if it is empty. With no item shown there, e.g. text or
  /// the end of the section, only an empty item is dropped.
  void _join(List<ChecklistBlock> section, MarkdownLine line, ItemJoin join) {
    final index = section.indexWhere((block) => block.first.id == line.id);
    if (index < 0) return;
    final step = join == ItemJoin.above ? -1 : 1;
    final neighbor = index + step < 0
        ? null
        : section.elementAtOrNull(index + step);
    if (neighbor is! ItemBlock) {
      if (line.text.isEmpty) _drop(line, join);
      return;
    }
    final other = neighbor.first;
    switch (join) {
      case ItemJoin.above:
        _editor.join(line.id, into: other.id);
        _focus.focusLater(other.id, caret: other.text.length);
      case ItemJoin.below when line.text.isEmpty:
        _editor.join(line.id, into: other.id);
        _focus.focusLater(other.id, caret: 0);
      case ItemJoin.below:
        _editor.join(other.id, into: line.id);
        _focus.focusLater(line.id, caret: line.text.length);
    }
  }

  /// Drops the empty item [line] and moves the cursor to the row next to
  /// it: above for Backspace, unless that is the top add row, which may
  /// go with the item; else below.
  void _drop(MarkdownLine line, ItemJoin join) {
    final above = _focus.near(line.id, -1);
    final target =
        join == ItemJoin.above && above != null && above != _addTopKey
        ? above
        : (_focus.near(line.id, 1) ?? above);
    _editor.removeLine(line.id);
    if (target == null) return;
    final caret = switch (target) {
      final int id when join == ItemJoin.above =>
        _editor.list.lines.firstWhere((other) => other.id == id).text.length,
      int() => 0,
      _ => null,
    };
    _focus.focusLater(target, caret: caret);
  }

  @override
  Widget build(BuildContext context) {
    final separateDone = widget.separateDone;
    return ListenableBuilder(
      listenable: _editor,
      builder: (context, _) {
        final list = _editor.list;
        final done = separateDone ? list.doneIds : const <int>{};
        final open = blocksOf(
          list.lines.where((line) => !done.contains(line.id)),
        );
        final doneBlocks = blocksOf(
          list.lines.where((line) => done.contains(line.id)),
        );
        // The add rows sit right above the first open item and right below
        // the last; without open items, one row adds below all.
        final (:head, :body, :tail) = splitAtItems(open);
        final items = [
          for (final ItemBlock(:first) in body.whereType<ItemBlock>()) first,
        ];
        Widget row(ChecklistBlock block, List<ChecklistBlock> section) =>
            _row(list, block, section);
        _focus.show([
          if (items.isNotEmpty) _addTopKey,
          for (final item in items) item.id,
          _addRowKey,
          if (_doneExpanded)
            for (final ItemBlock(:first) in doneBlocks.whereType<ItemBlock>())
              first.id,
        ]);
        return CustomScrollView(
          // Pulls down even when the items fit, to refresh.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverList.list(
              children: [for (final block in head) row(block, open)],
            ),
            if (items.isNotEmpty)
              SliverToBoxAdapter(
                child: _addRow(
                  _addTopKey,
                  _newTopItem,
                  (text) => _editor.insertBefore(items.first.id, text),
                  hint: 'Add item at top',
                ),
              ),
            SliverReorderableList(
              itemCount: body.length,
              itemBuilder: (context, index) =>
                  _row(list, body[index], open, index: index),
              // The dragged row floats outside the page, so it needs its
              // own Material for its checkbox and text field.
              proxyDecorator: (child, _, _) =>
                  Material(elevation: 4, child: child),
              onReorderItem: (from, to) {
                final rest = [...body]..removeAt(from);
                final before = to < rest.length ? rest[to] : tail.firstOrNull;
                _editor.move(body[from].first.id, beforeId: before?.first.id);
              },
            ),
            SliverToBoxAdapter(
              child: _addRow(
                _addRowKey,
                _newItem,
                (text) => items.isEmpty
                    ? _editor.append(text)
                    : _editor.appendAfter(items.last.id, text),
                hint: 'Add item',
              ),
            ),
            SliverList.list(
              children: [for (final block in tail) row(block, open)],
            ),
            if (doneBlocks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _doneHeader(
                  list.lines.where((line) => line.isChecked).length,
                ),
              ),
              if (_doneExpanded)
                SliverList.list(
                  children: [
                    for (final block in doneBlocks) row(block, doneBlocks),
                  ],
                ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
          ],
        );
      },
    );
  }

  /// [block] of [section] (open or done blocks); [index] is set for rows in
  /// the reorderable list.
  Widget _row(
    MarkdownLines list,
    ChecklistBlock block,
    List<ChecklistBlock> section, {
    int? index,
  }) {
    final line = block.first;
    if (block case TextBlock(:final markdown)) {
      return ChecklistTextBlock(markdown, key: ValueKey(line.id));
    }
    return ChecklistItemRow(
      key: ValueKey(line.id),
      line: line,
      depth: list.depthOf(line),
      focusNode: _focus.of(line.id),
      onFocusStep: (step) => _focus.move(line.id, step),
      onJoin: (join) => _join(section, line, join),
      takeCaret: () => _focus.takeCaret(line.id),
      dragHandle: index == null
          ? null
          : (icon) => ReorderableDragStartListener(index: index, child: icon),
      onToggle: () => _editor.toggle(line.id, sort: widget.checkedToEnd),
      onTextChanged: (text) => _editor.setText(line.id, text),
      onSubmitted: () => _focus.focusLater(_editor.insertAfter(line.id)),
      onAction: (action) => _onAction(line, action),
    );
  }

  /// A field that starts an item with [add]; [key] is its row in [_focus].
  /// Lined up with the item rows: its icon in their box's place.
  Widget _addRow(
    String key,
    TextEditingController field,
    int Function(String text) add, {
    required String hint,
  }) => Row(
    children: [
      const SizedBox(width: checklistHandleWidth),
      const ChecklistBoxSlot(Icon(Icons.add)),
      Expanded(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _focus.move(key, -1),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _focus.move(key, 1),
          },
          child: Focus(
            onFocusChange: (focused) {
              if (!focused) _endItem(field);
            },
            child: TextField(
              controller: field,
              focusNode: _focus.of(key),
              decoration: checklistFieldDecoration(hint: hint),
              onChanged: (typed) => _startItem(field, add, typed),
            ),
          ),
        ),
      ),
      // Where the item rows have their menu.
      const SizedBox(width: kMinInteractiveDimension),
    ],
  );

  Widget _doneHeader(int count) => ListTile(
    leading: Icon(_doneExpanded ? Icons.expand_less : Icons.expand_more),
    title: Text('$count done'),
    onTap: () => setState(() => _doneExpanded = !_doneExpanded),
    trailing: TextButton(
      onPressed: () => _offerUndo('Done items cleared', _editor.clearDone()),
      child: const Text('Clear done'),
    ),
  );
}
