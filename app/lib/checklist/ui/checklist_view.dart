import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../checklist_editor.dart';
import '../checklist_settings.dart';
import 'checklist_row.dart';

/// Keep-like view of a checklist: open items to drag and edit, an add row,
/// and checked items in a collapsible "Done" section.
class ChecklistView extends ConsumerStatefulWidget {
  const ChecklistView(this.editor, {super.key});

  final ChecklistEditor editor;

  @override
  ConsumerState<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends ConsumerState<ChecklistView> {
  final _newItem = TextEditingController();
  final _newItemFocus = FocusNode();
  int? _focusId;
  bool _doneExpanded = true;

  ChecklistEditor get _editor => widget.editor;

  @override
  void dispose() {
    _newItem.dispose();
    _newItemFocus.dispose();
    super.dispose();
  }

  void _addItem(String text) {
    if (text.trim().isEmpty) return;
    _editor.append(text.trim());
    _newItem.clear();
    _newItemFocus.requestFocus();
  }

  void _onAction(ChecklistLine line, ItemAction action) {
    switch (action) {
      case ItemAction.indent:
        _editor.indent(line.id);
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
        final open = [
          for (final line in list.lines)
            if (line.raw.trim().isNotEmpty && !done.contains(line.id)) line,
        ];
        final doneLines = [
          for (final line in list.lines)
            if (done.contains(line.id)) line,
        ];
        return CustomScrollView(
          slivers: [
            SliverReorderableList(
              itemCount: open.length,
              itemBuilder: (context, index) =>
                  _row(list, open[index], index: index),
              onReorderItem: (from, to) {
                final rest = [...open]..removeAt(from);
                _editor.move(
                  open[from].id,
                  beforeId: to < rest.length ? rest[to].id : null,
                );
              },
            ),
            SliverToBoxAdapter(child: _addRow()),
            if (doneLines.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _doneHeader(
                  doneLines.where((line) => line.isItem).length,
                ),
              ),
              if (_doneExpanded)
                SliverList.list(
                  children: [for (final line in doneLines) _row(list, line)],
                ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
          ],
        );
      },
    );
  }

  /// [index] is set for rows in the reorderable list.
  Widget _row(Checklist list, ChecklistLine line, {int? index}) {
    if (!line.isItem) {
      return ChecklistTextRow(line, key: ValueKey(line.id));
    }
    return ChecklistItemRow(
      key: ValueKey(line.id),
      line: line,
      depth: list.depthOf(line),
      autofocus: line.id == _focusId,
      dragHandle: index == null
          ? null
          : (icon) => ReorderableDragStartListener(index: index, child: icon),
      onToggle: () => _editor.toggle(line.id),
      onTextChanged: (text) => _editor.setText(line.id, text),
      onSubmitted: () =>
          setState(() => _focusId = _editor.insertAfter(line.id)),
      onAction: (action) => _onAction(line, action),
    );
  }

  Widget _addRow() => Padding(
    padding: const EdgeInsets.only(left: 24),
    child: Row(
      children: [
        const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.add)),
        Expanded(
          child: TextField(
            controller: _newItem,
            focusNode: _newItemFocus,
            decoration: const InputDecoration(
              hintText: 'Add item',
              border: InputBorder.none,
            ),
            onSubmitted: _addItem,
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
