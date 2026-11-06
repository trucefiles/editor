import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// What the page gives every editor's view: the file's text as last
/// [kept] (e.g. for a view that only reads), where the file is now
/// ([folder], [path]; it changes with a move, or a new file's first
/// line), how to read another file of its folder ([bytesOf], e.g. an
/// image it links; `null` if it can't be read), how a short [hint]
/// shows (e.g. a link it doesn't open), and the file's [color]. What a
/// type needs beyond this, it gets from its own wiring.
final class EditorHost {
  const EditorHost({
    required this.kept,
    required this.folder,
    required this.path,
    required this.bytesOf,
    required this.hint,
    required this.color,
  });

  final String kept;
  final FolderId folder;
  final RelPath path;
  final Future<Uint8List?> Function(RelPath path) bytesOf;
  final void Function(String message) hint;

  /// The file's color as the app shows it (its own, else its folder's),
  /// for a type that draws in it (e.g. a calendar's events).
  final Color color;
}

/// How a file type's editor part shows on the page: the editor in
/// the mode it shows, and what the type adds to the page while the
/// file can be edited (by default nothing). Read again each time the
/// part's changes fire.
abstract base class EditorView {
  const EditorView();

  /// The editor, as it shows now, on [host]; with the caret in it right
  /// away if [autofocus] (e.g. a new file).
  Widget view(EditorHost host, {required bool autofocus});

  /// The title in the app bar: [fileTitle], the file's title as the page
  /// shows it, or the type's own in its place (e.g. a calendar's name,
  /// edited right there). [nameTitle] is the title from the file's name
  /// alone, whatever its text says.
  Widget title(
    BuildContext context,
    Widget fileTitle, {
    required String nameTitle,
  }) => fileTitle;

  /// What the type adds to the app bar (e.g. the mode menu).
  List<Widget> actions(BuildContext context) => const [];

  /// What the type adds to the file's menu, by its [view] settings
  /// now; [context] is the page's.
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  ) => const [];

  /// The type's keys.
  Map<SingleActivator, VoidCallback> get keys => const {};

  /// The type's floating button (e.g. a calendar's Add), shown while the
  /// file can be edited; `null` for none.
  Widget? floatingButton(BuildContext context) => null;
}
