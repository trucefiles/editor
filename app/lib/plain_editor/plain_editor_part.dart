import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import '../document_page/editor_part.dart';
import '../documents/document_settings.dart';
import '../editor/lines/line_edit_view.dart';
import 'plain_page_editor.dart';
import 'plain_text.dart';
import 'ui/plain_look.dart';
import 'ui/plain_read_view.dart';

/// A plain text document's part of the document page: its editor owner,
/// edited line by line as written, or only read while it can't be
/// edited. Adds nothing else to the page.
final class PlainEditorPart extends ChangeNotifier implements EditorPart {
  PlainEditorPart(EditorStart start)
    : _owner = plainOwner(start.text, version: start.version),
      _readOnly = start.readOnly;

  final PlainOwner _owner;
  late final _text = PlainText(_owner);

  @override
  late final PageEditor editor = PlainPageEditor(_owner);

  bool _readOnly;

  @override
  void showReadOnly({required bool readOnly}) {
    if (readOnly == _readOnly) return;
    _readOnly = readOnly;
    notifyListeners();
  }

  @override
  bool get isEditing => !_readOnly;

  @override
  void settingsChanged(DocumentSettings settings) {}

  /// While read only, the text as last kept.
  @override
  Widget view(EditorPlace place, {required bool autofocus}) => _readOnly
      ? PlainReadView(place.kept, key: const ValueKey(#read))
      : LineEditView<TextLines>(
          _text,
          key: const ValueKey(#edit),
          editing: plainLines,
          autofocus: autofocus,
        );

  @override
  List<Widget> actions(BuildContext context) => const [];

  @override
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    DocumentSettings settings,
  ) => const [];

  @override
  Map<SingleActivator, VoidCallback> get keys => const {};
}

/// A plain text's lines: read as written, drawn as plain text.
final plainLines = LineEditing<TextLines>(
  read: TextLines.read,
  look: (theme, metrics) => plainLook(theme, metrics: metrics),
);
