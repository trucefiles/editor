import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// What the page gives every editor's view: the file's text as last
/// [kept] (e.g. for a view that only reads), where the file is now
/// ([folder], [path]; it changes with a move, or a new file's first
/// line), how to read another file of its folder ([bytesOf], e.g. an
/// image it links; `null` if it can't be read), how a short [hint]
/// shows (e.g. a link it doesn't open), the file's [color], and the
/// [images] the app keeps for its text. What a type needs beyond this,
/// it gets from its own wiring.
final class EditorHost {
  const EditorHost({
    required this.kept,
    required this.folder,
    required this.path,
    required this.bytesOf,
    required this.hint,
    required this.color,
    this.images = const NoHostImages(),
  });

  final String kept;
  final FolderId folder;
  final RelPath path;
  final Future<Uint8List?> Function(RelPath path) bytesOf;
  final void Function(String message) hint;

  /// The file's color as the app shows it (its own, else its folder's),
  /// for a type that draws in it (e.g. a calendar's events).
  final Color color;

  final HostImages images;
}

/// The images the app keeps for a file's text in its folder, wherever
/// the file is now: where a link of ours leads, adding one, and how
/// links of ours change in text pasted into the file.
abstract interface class HostImages {
  /// Where the image [link] names is kept, wherever the link points;
  /// `null` for a link whose name isn't ours. It may not be there.
  RelPath? keptAt(String link);

  /// Keeps [bytes], an image with [extension] (without its dot), for the
  /// file: the link to write in its text. Fails if the folder can't be
  /// written (e.g. it can't be reached).
  Future<Result<String, StoreError>> add(
    Uint8List bytes, {
    required String extension,
  });

  /// How the links of ours in text pasted into the file change, so they
  /// lead to their images from where it is; `null` if that can't be
  /// told now.
  Future<Relink?> pasteRelink();
}

/// A file for which no images are kept.
final class NoHostImages implements HostImages {
  const NoHostImages();

  @override
  RelPath? keptAt(String link) => null;

  @override
  Future<Result<String, StoreError>> add(
    Uint8List bytes, {
    required String extension,
  }) async => const Err(StoreError.outside);

  @override
  Future<Relink?> pasteRelink() async => null;
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
