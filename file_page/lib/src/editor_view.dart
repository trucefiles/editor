import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// What the page gives every editor's view: the file's text as last
/// [kept] (e.g. for a view that only reads), where the file is now
/// ([folder], [path]; it changes with a move, or a new file's first
/// line), how to read another file of its folder ([bytesOf], e.g. an
/// image it links; `null` if it can't be read), and how a short [hint]
/// shows (e.g. a link it doesn't open). What a type needs beyond this,
/// it gets from its own wiring.
final class EditorHost {
  const EditorHost({
    required this.kept,
    required this.folder,
    required this.path,
    required this.bytesOf,
    required this.hint,
  });

  final String kept;
  final FolderId folder;
  final RelPath path;
  final Future<Uint8List?> Function(RelPath path) bytesOf;
  final void Function(String message) hint;
}

/// How a file type's editor part shows on the page: the editor in
/// the mode it shows, and what the type adds to the page while the
/// file can be edited. Read again each time the part's changes fire.
abstract interface class EditorView {
  /// The editor, as it shows now, on [host]; with the caret in it right
  /// away if [autofocus] (e.g. a new file).
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
