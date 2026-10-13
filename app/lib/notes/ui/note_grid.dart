import 'package:flutter/material.dart';

import '../note.dart';
import 'note_editor_screen.dart';

/// Card layout shared by every note grid.
const noteGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
  mainAxisExtent: 200,
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
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
