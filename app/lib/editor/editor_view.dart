import 'package:flutter/material.dart';

import '../documents/view_settings.dart';
import 'add_item_place/add_item_place.dart';
import 'ui/document_image.dart';

/// What the page gives an editor's view: the document's text as last
/// [kept] (e.g. for a view that only reads), where lists get Add item
/// buttons ([addItems]), how a web or mail link opens ([openLink]), and
/// the document's [images].
typedef EditorHost = ({
  String kept,
  AddItemPlace addItems,
  Future<void> Function(Uri link) openLink,
  DocumentImages images,
});

/// How a document type's editor part shows on the page: the editor in
/// the mode it shows, and what the type adds to the page while the
/// document can be edited. Read again each time the part's changes fire.
abstract interface class EditorView {
  /// The editor, as it shows now, on [host]; with the caret in it right
  /// away if [autofocus] (e.g. a new document).
  Widget view(EditorHost host, {required bool autofocus});

  /// What the type adds to the app bar (e.g. the mode menu).
  List<Widget> actions(BuildContext context);

  /// What the type adds to the document's menu, by its [view] settings
  /// now; [context] is the page's.
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  );

  /// The type's keys.
  Map<SingleActivator, VoidCallback> get keys;
}
