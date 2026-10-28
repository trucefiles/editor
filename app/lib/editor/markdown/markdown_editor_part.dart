import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../../document_page/editor_part.dart';
import '../../documents/document_files.dart';
import '../../documents/document_images.dart';
import '../../documents/document_settings.dart';
import '../../documents/ui/checked_items_dialog.dart';
import '../../documents/ui/edit_mode_button.dart';
import '../../markdown/markdown_links.dart';
import '../add_item_place/add_item_place.dart';
import '../add_item_place/add_item_place_controller.dart';
import '../document_editor.dart';
import '../editor_gate.dart';
import '../first_mode.dart';
import '../run_command.dart';
import 'markdown_page_editor.dart';

/// A Markdown document's part of the document page: its editor owner,
/// behind a gate, in the mode the user picked (remembered on this device)
/// or in Read while it can't be edited; the mode menu and Ctrl+1, 2, 3;
/// and the menu's commands on checked items.
final class MarkdownEditorPart extends ChangeNotifier implements EditorPart {
  MarkdownEditorPart(EditorStart start, this._page)
    : _mode =
          start.settings.mode ??
          firstMode(
            hasCheckboxes:
                !start.isNew && DocumentSummary.of(start.text).hasCheckboxes,
            typing: start.isNew,
          ),
      _readOnly = start.readOnly {
    editor = MarkdownPageEditor(
      EditorGate(
        editorOwner(
          start.text,
          version: start.version,
          mode: _shown,
          checkedItems: start.settings.checkedItems,
        ),
      ),
    );
  }

  final EditorPage _page;

  @override
  late final MarkdownPageEditor editor;

  EditorGate get _gate => editor.gate;

  /// The mode the user picked last.
  EditMode _mode;

  bool _readOnly;

  /// The mode that shows: Read while the document can't be edited.
  EditMode get _shown => _readOnly ? EditMode.read : _mode;

  @override
  void showReadOnly({required bool readOnly}) {
    _readOnly = readOnly;
    _showShown();
  }

  @override
  bool get isEditing => _shown != EditMode.read;

  void _showShown() {
    final shown = _shown;
    if (_gate.state.mode != shown) _gate.send((_) => SetMode(shown));
  }

  /// Shows [mode] from now on, and remembers it on this device.
  void _pick(EditMode mode) {
    _mode = mode;
    _page.keepSettings((settings) => settings.withMode(mode));
    _showShown();
    notifyListeners();
  }

  @override
  void settingsChanged(DocumentSettings settings) {
    final checkedItems = settings.checkedItems;
    if (_gate.state.checkedItems != checkedItems) {
      _gate.send((_) => SetCheckedItems(checkedItems));
    }
  }

  @override
  Widget view(EditorPlace place, {required bool autofocus}) =>
      _MarkdownView(_gate, place: place, autofocus: autofocus);

  @override
  List<Widget> actions(BuildContext context) => [
    EditModeButton(mode: _mode, onChanged: _pick),
  ];

  /// Ctrl+1, 2, 3 pick the modes in the mode menu's order.
  @override
  late final Map<SingleActivator, VoidCallback> keys = {
    for (final (index, mode) in EditMode.values.indexed)
      SingleActivator(_digits[index], control: true): () {
        if (mode != _mode) _pick(mode);
      },
  };

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  /// Whether the document has checklist items. Read when the menu opens.
  bool get _hasCheckboxes => switch (_gate.state.content) {
    FormattedContent(:final view) => view.doc.hasCheckboxes,
    MarkdownContent(:final text) => DocumentSummary.of(text).hasCheckboxes,
  };

  @override
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    DocumentSettings settings,
  ) => [
    if (_hasCheckboxes) ...[
      // In Visual edit and Read.
      if (_gate.state.mode != EditMode.markdown) ...[
        PopupMenuItem(
          value: () => _gate.run(MoveToEnd.new),
          child: const Text('Move checked items to end now'),
        ),
        PopupMenuItem(
          value: () => _gate.run(ClearChecked.new),
          child: const Text('Clear checked items now'),
        ),
      ],
      PopupMenuItem(
        value: () => _page.withFile(
          context,
          (_) => _pickCheckedItems(context, settings.checkedItems),
        ),
        child: Text(
          'Checked items: ${checkedItemsName(settings.checkedItems)}',
        ),
      ),
    ],
  ];

  /// Asks how the document's checked items show, on this device; nothing
  /// moves.
  Future<void> _pickCheckedItems(
    BuildContext context,
    CheckedItems current,
  ) async {
    final chosen = await showCheckedItemsDialog(context, current: current);
    if (chosen == null || chosen == current) return;
    _page.keepSettings((settings) => settings.withCheckedItems(chosen));
  }
}

/// The editor in the mode it shows; lists get Add item buttons where the
/// setting says, links open in the browser, images show from the web or
/// the folder.
class _MarkdownView extends ConsumerWidget {
  const _MarkdownView(
    this.gate, {
    required this.place,
    required this.autofocus,
  });

  final EditorGate gate;
  final EditorPlace place;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DocumentEditor(
    gate,
    text: place.kept,
    notices: gate.events,
    addItems: ref.watch(addItemPlaceProvider).value ?? AddItemPlace.top,
    onLink: (url) => openMarkdownLink(context, ref, url),
    images: documentImages(
      ref.read(documentFilesProvider(place.folder)),
      folder: place.folder,
      document: place.path,
    ),
    autofocus: autofocus,
  );
}
