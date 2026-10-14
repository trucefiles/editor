import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../note.dart';
import 'note_editor_screen.dart';

/// [cards] in columns up to 240 wide, each card as tall as its content:
/// the layout shared by every note grid.
Widget noteGrid(List<Widget> cards) => SliverMasonryGrid(
  gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 240,
  ),
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
  delegate: SliverChildListDelegate(cards),
);

/// Opens [note] in the editor.
Future<void> openNote(
  BuildContext context,
  Note note, {
  bool autofocus = false,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => NoteEditorScreen(note, autofocus: autofocus),
  ),
);
