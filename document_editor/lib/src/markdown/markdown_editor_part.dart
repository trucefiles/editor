import 'dart:async';

import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../editor_gate.dart';
import '../first_mode.dart';
import 'markdown_page_editor.dart';
import 'markdown_view.dart';

/// A Markdown document's part of the document page: its editor owner,
/// behind a gate, in the mode the user picked (remembered on this device)
/// or in Read while it can't be edited; and the commands on checked
/// items.
final class MarkdownEditorPart implements EditorPart {
  MarkdownEditorPart(EditorStart start, EditorPage page)
    : this._read(MarkdownStart.read(start.text), start, page);

  MarkdownEditorPart._read(MarkdownStart read, EditorStart start, this._page)
    : _mode =
          MarkdownView.of(start.view).mode ??
          firstMode(
            hasCheckboxes: !start.isNew && read.hasCheckboxes,
            typing: start.isNew,
          ),
      _readOnly = start.readOnly {
    editor = MarkdownPageEditor(
      EditorGate(
        editorOwner(
          read,
          version: start.version,
          mode: _shown,
          checkedItems: MarkdownView.of(start.view).checkedItems,
        ),
      ),
    );
  }

  final EditorPage _page;

  @override
  late final MarkdownPageEditor editor;

  /// The editor owner, behind its gate.
  EditorGate get gate => editor.gate;

  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get changes => _changes.stream;

  /// The mode the user picked last.
  EditMode get mode => _mode;
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
    if (gate.state.mode != shown) gate.send((_) => SetMode(shown));
  }

  /// Shows [mode] from now on, and remembers it on this device.
  void pick(EditMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _page.keepView((view) => MarkdownView.of(view).withMode(mode).settings);
    _showShown();
    _changes.add(null);
  }

  @override
  void viewChanged(ViewSettings view) {
    final checkedItems = MarkdownView.of(view).checkedItems;
    if (gate.state.checkedItems != checkedItems) {
      gate.send((_) => SetCheckedItems(checkedItems));
    }
  }

  /// Whether the document has checklist items now.
  bool get hasCheckboxes => switch (gate.state.content) {
    FormattedContent(:final view) => view.doc.hasCheckboxes,
    MarkdownContent(:final text) => DocumentSummary.of(text).hasCheckboxes,
  };

  /// Keeps how the document's checked items show on this device, as
  /// [ask]ed from [current] once the document has a file; nothing moves.
  /// Keeps nothing if the user picks none, or [current].
  Future<void> chooseCheckedItems(
    CheckedItems current,
    Future<CheckedItems?> Function(CheckedItems current) ask,
  ) => _page.withFile((_) async {
    final chosen = await ask(current);
    if (chosen == null || chosen == current) return;
    _page.keepView(
      (view) => MarkdownView.of(view).withCheckedItems(chosen).settings,
    );
  });

  @override
  void dispose() => unawaited(_changes.close());
}
