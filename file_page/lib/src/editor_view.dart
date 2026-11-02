import 'package:flutter/material.dart';
import 'package:truce_files/truce_files.dart';

/// What the page gives every editor's view: the file's text as last
/// [kept] (e.g. for a view that only reads), and how a short [hint]
/// shows (e.g. a link it doesn't open). A type that needs more gets a
/// host that extends this one.
class EditorHost {
  const EditorHost({required this.kept, required this.hint});

  final String kept;
  final void Function(String message) hint;
}

/// How a file type's editor part shows on the page: the editor in
/// the mode it shows, and what the type adds to the page while the
/// file can be edited. Read again each time the part's changes fire.
abstract interface class EditorView {
  /// The editor, as it shows now, on [host]; with the caret in it right
  /// away if [autofocus] (e.g. a new file).
  ///
  /// The page gives every view the richest host the app has (today a
  /// text editor's `TextHost`), so a view may take a host of its own
  /// package's kind (`covariant`); a view that needs a new kind of host
  /// changes the page to give it.
  Widget view(EditorHost host, {required bool autofocus});

  /// What the type adds to the app bar (e.g. the mode menu).
  List<Widget> actions(BuildContext context);

  /// What the type adds to the file's menu, by its [view] settings
  /// now; [context] is the page's.
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  );

  /// The type's keys.
  Map<SingleActivator, VoidCallback> get keys;
}
