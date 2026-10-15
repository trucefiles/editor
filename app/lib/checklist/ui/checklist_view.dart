import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../checklist_editor.dart';
import '../checklist_settings.dart';
import 'checklist_blocks.dart';
import 'checklist_row.dart';
import 'checklist_text_block.dart';
import 'checklist_undo_hint.dart';
import 'row_focus.dart';

/// Keep-like view of a checklist: open items to drag and edit, add rows
/// above and below them, and checked items in a collapsible "Done"
/// section.
class ChecklistView extends ConsumerStatefulWidget {
  const ChecklistView(this.editor, {super.key});

  final ChecklistEditor editor;

  @override
  ConsumerState<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends ConsumerState<ChecklistView> {
  /// Row keys of the add fields in [_focus].
  static const _addTopKey = 'add top';
  static const _addRowKey = 'add';

  final _newTopItem = TextEditingController();
  final _newItem = TextEditingController();
  final _focus = RowFocus();
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
  /// it is in the note and saved like any other edit.
  void _startItem(
    TextEditingController field,
    int Function(String text) add,
    String typed,
  ) {
    final text = typed.trimLeft();
    if (text.isEmpty) return;
    field.clear();
    _focus.focusLater(add(text));
  }

  void _onAction(ChecklistLine line, ItemAction action) {
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
  Set<int> _hiddenFrom(ChecklistLine line) {
    if (!ref.read(doneSectionProvider)) return const {};
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

  @override
  Widget build(BuildContext context) {
    final separateDone = ref.watch(doneSectionProvider);
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
        // Above the items only when there are some: else both rows would
        // add at the same place.
        final hasOpenItems = open.any((block) => block is ItemBlock);
        _focus.show([
          if (hasOpenItems) _addTopKey,
          for (final ItemBlock(:first) in open.whereType<ItemBlock>()) first.id,
          _addRowKey,
          if (_doneExpanded)
            for (final ItemBlock(:first) in doneBlocks.whereType<ItemBlock>())
              first.id,
        ]);
        return CustomScrollView(
          slivers: [
            if (hasOpenItems)
              SliverToBoxAdapter(
                child: _addRow(
                  _addTopKey,
                  _newTopItem,
                  _editor.prepend,
                  hint: 'Add item at top',
                ),
              ),
            SliverReorderableList(
              itemCount: open.length,
              itemBuilder: (context, index) =>
                  _row(list, open[index], index: index),
              // The dragged row floats outside the page, so it needs its
              // own Material for its checkbox and text field.
              proxyDecorator: (child, _, _) =>
                  Material(elevation: 4, child: child),
              onReorderItem: (from, to) {
                final rest = [...open]..removeAt(from);
                _editor.move(
                  open[from].first.id,
                  beforeId: to < rest.length ? rest[to].first.id : null,
                );
              },
            ),
            SliverToBoxAdapter(
              child: _addRow(
                _addRowKey,
                _newItem,
                _editor.append,
                hint: 'Add item',
              ),
            ),
            if (doneBlocks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _doneHeader(doneBlocks.whereType<ItemBlock>().length),
              ),
              if (_doneExpanded)
                SliverList.list(
                  children: [for (final block in doneBlocks) _row(list, block)],
                ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
          ],
        );
      },
    );
  }

  /// [index] is set for rows in the reorderable list.
  Widget _row(Checklist list, ChecklistBlock block, {int? index}) {
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
      dragHandle: index == null
          ? null
          : (icon) => ReorderableDragStartListener(index: index, child: icon),
      onToggle: () => _editor.toggle(line.id),
      onTextChanged: (text) => _editor.setText(line.id, text),
      onSubmitted: () => _focus.focusLater(_editor.insertAfter(line.id)),
      onAction: (action) => _onAction(line, action),
    );
  }

  /// A field that starts an item with [add]; [key] is its row in [_focus].
  Widget _addRow(
    String key,
    TextEditingController field,
    int Function(String text) add, {
    required String hint,
  }) => Padding(
    padding: const EdgeInsets.only(left: 24),
    child: Row(
      children: [
        const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.add)),
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _focus.move(key, -1),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _focus.move(key, 1),
            },
            child: TextField(
              controller: field,
              focusNode: _focus.of(key),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
              onChanged: (typed) => _startItem(field, add, typed),
            ),
          ),
        ),
      ],
    ),
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
