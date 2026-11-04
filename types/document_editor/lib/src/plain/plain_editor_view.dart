import 'package:flutter/material.dart';
import 'package:truce_file_page/truce_file_page.dart';

import '../lines/line_edit_view.dart';
import 'plain_editor_part.dart';
import 'plain_text.dart';
import 'ui/plain_look.dart';
import 'ui/plain_read_view.dart';

/// How a plain text document's part shows: its lines to edit, or only
/// its text to read. Adds nothing else to the page.
final class PlainEditorView extends EditorView {
  PlainEditorView(this._part) : _text = PlainText(_part.owner);

  final PlainEditorPart _part;
  final PlainText _text;

  /// While read only, the editor's text, its latest edits too (they may
  /// not be kept yet).
  @override
  Widget view(EditorHost host, {required bool autofocus}) => _part.isEditing
      ? LineEditView(
          _text,
          key: const ValueKey(#edit),
          editing: plainLines,
          autofocus: autofocus,
        )
      : ListenableBuilder(
          key: const ValueKey(#read),
          listenable: _text,
          builder: (_, _) => PlainReadView(_text.shown.text),
        );
}

/// A plain text's lines: drawn as plain text.
final plainLines = LineEditing(
  look: (theme, metrics) => plainLook(theme, metrics: metrics),
);
