import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../documents/view_settings.dart';
import '../folders/document_folder.dart';

/// Where an open document's editor starts: the [text] it opens with (read
/// as [version], `null` for a new document), what its type keeps of how it
/// shows on this device ([view]), whether it opens [readOnly], and whether
/// it is [isNew].
typedef EditorStart = ({
  String text,
  Version? version,
  ViewSettings view,
  bool readOnly,
  bool isNew,
});

/// What the document page gives an editor part.
final class EditorPage {
  const EditorPage({required this.keepView, required this.withFile});

  /// Changes what the type keeps of how the document shows on this
  /// device; for a new document, once it has a file.
  final void Function(ViewSettings Function(ViewSettings) change) keepView;

  /// Runs an action on the document's file, created first for a new
  /// document; the page tells the user if there is none. The context is
  /// the page's.
  final Future<void> Function(
    BuildContext context,
    FutureOr<void> Function(Document document) action,
  )
  withFile;
}

/// Where the editor shows: the document's [folder] and file [path], and
/// its text as last kept ([kept]), e.g. for a view that only reads.
typedef EditorPlace = ({DocumentFolder folder, RelPath path, String kept});

/// The part of the one text document page that differs per document
/// type: its editor, behind the page's way into it ([editor]), and what
/// the type adds to the page. Listeners hear when the page shows the
/// part differently (e.g. another mode picked).
abstract interface class EditorPart implements Listenable {
  /// The page's way into the editor owner.
  PageEditor get editor;

  /// Shows the document only to read while [readOnly] (it can't be
  /// edited here now), else as the user picked.
  void showReadOnly({required bool readOnly});

  /// Whether the editor shows the text to edit (undo and redo work), not
  /// only to read.
  bool get isEditing;

  /// What the type keeps of how the document shows changed to [view].
  void viewChanged(ViewSettings view);

  /// The editor, as it shows now, at [place]; with the caret in it right
  /// away if [autofocus] (e.g. a new document).
  Widget view(EditorPlace place, {required bool autofocus});

  /// What the type adds to the app bar while the document can be edited
  /// (e.g. the mode menu).
  List<Widget> actions(BuildContext context);

  /// What the type adds to the document's menu while it can be edited,
  /// by its [view] settings now; [context] is the page's.
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  );

  /// The type's keys while the document can be edited.
  Map<SingleActivator, VoidCallback> get keys;

  /// The page is gone; its editor is closed with the page's session.
  void dispose();
}
