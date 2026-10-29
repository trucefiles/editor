import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../../documents/view_settings.dart';
import '../document_editor.dart';
import '../editor_view.dart';
import '../run_command.dart';
import 'markdown_editor_part.dart';
import 'markdown_links.dart';
import 'markdown_view.dart';
import 'ui/checked_items_dialog.dart';
import 'ui/edit_mode_button.dart';

/// How a Markdown document's part shows: the editor in the mode it shows,
/// the mode menu and Ctrl+1, 2, 3, and the menu's commands on checked
/// items.
final class MarkdownEditorView implements EditorView {
  MarkdownEditorView(this._part);

  final MarkdownEditorPart _part;

  /// Lists get Add item buttons where the host says, links open as the
  /// host opens them, images show as the host finds them.
  @override
  Widget view(EditorHost host, {required bool autofocus}) => Builder(
    builder: (context) => DocumentEditor(
      _part.gate,
      text: host.kept,
      notices: _part.gate.events,
      addItems: host.addItems,
      onLink: (url) => openMarkdownLink(context, url, open: host.openLink),
      images: host.images,
      autofocus: autofocus,
    ),
  );

  @override
  List<Widget> actions(BuildContext context) => [
    EditModeButton(mode: _part.mode, onChanged: _part.pick),
  ];

  /// Ctrl+1, 2, 3 pick the modes in the mode menu's order.
  @override
  late final Map<SingleActivator, VoidCallback> keys = {
    for (final (index, mode) in EditMode.values.indexed)
      SingleActivator(_digits[index], control: true): () => _part.pick(mode),
  };

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  @override
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  ) {
    final gate = _part.gate;
    final checkedItems = MarkdownView.of(view).checkedItems;
    return [
      if (_part.hasCheckboxes) ...[
        // Only Visual edit acts on the document from its menu; Read shows
        // the standard reading, which the editor's commands don't act on.
        if (gate.state.mode == EditMode.visual) ...[
          PopupMenuItem(
            value: () => gate.run(MoveToEnd.new),
            child: const Text('Move checked items to end now'),
          ),
          PopupMenuItem(
            value: () => gate.run(ClearChecked.new),
            child: const Text('Clear checked items now'),
          ),
        ],
        PopupMenuItem(
          value: () => _part.chooseCheckedItems(
            checkedItems,
            (current) => showCheckedItemsDialog(context, current: current),
          ),
          child: Text('Checked items: ${checkedItemsName(checkedItems)}'),
        ),
      ],
    ];
  }
}
