import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../checklist_editor.dart';
import '../checklist_settings.dart';
import 'checklist_blocks.dart';
import 'checklist_row.dart';
import 'checklist_text_block.dart';
import 'row_focus.dart';

/// Keep-like view of a checklist: open items to drag and edit, an add row,
/// and checked items in a collapsible "Done" section.
class ChecklistView extends ConsumerStatefulWidget {
  const ChecklistView(this.editor, {super.key});

  final ChecklistEditor editor;

  @override
  ConsumerState<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends ConsumerState<ChecklistView> {
  /// Row key of the "Add item" field in [_focus].
  static const _addRowKey = 'add';

  final _newItem = TextEditingController();
  final _focus = RowFocus();
  bool _doneExpanded = true;

  ChecklistEditor get _editor => widget.editor;

  @override
  void dispose() {
    _newItem.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addItem(String text) {
    if (text.trim().isEmpty) return;
    _editor.append(text.trim());
    _newItem.clear();
    _focus.of(_addRowKey).requestFocus();
  }

  void _onAction(ChecklistLine line, ItemAction action) {
    switch (action) {
      case ItemAction.indent:
        // Done items are shown in their own section, so they are not
        // "above" an open item on screen.
        final hidden = ref.read(doneSectionProvider)
            ? _editor.list.doneIds
            : const <int>{};
        _editor.indent(line.id, hidden: hidden);
      case ItemAction.outdent:
        _editor.outdent(line.id);
      case ItemAction.delete:
        final before = _editor.remove(line.id);
        _offerUndo('Item deleted', before);
    }
  }

  void _offerUndo(String message, String before) => showSnack(
    context,
    message,
    actionLabel: 'Undo',
    onAction: () => _editor.undo(before),
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
        _focus.show([
          for (final ItemBlock(:first) in open.whereType<ItemBlock>()) first.id,
          _addRowKey,
          if (_doneExpanded)
            for (final ItemBlock(:first) in doneBlocks.whereType<ItemBlock>())
              first.id,
        ]);
        return CustomScrollView(
          slivers: [
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
            SliverToBoxAdapter(child: _addRow()),
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

  Widget _addRow() => Padding(
    padding: const EdgeInsets.only(left: 24),
    child: Row(
      children: [
        const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.add)),
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _focus.move(_addRowKey, -1),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _focus.move(_addRowKey, 1),
            },
            child: TextField(
              controller: _newItem,
              focusNode: _focus.of(_addRowKey),
              decoration: const InputDecoration(
                hintText: 'Add item',
                border: InputBorder.none,
              ),
              onSubmitted: _addItem,
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
