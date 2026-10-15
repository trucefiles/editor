import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../folders/note_folder.dart';
import '../../folders/ui/folder_badge.dart';

/// The app bar of a screen comparing two versions of the note at [file] in
/// [folder]; [note], if given, tells below why there are two.
AppBar compareAppBar({
  required NoteFolder folder,
  required RelPath file,
  String? note,
}) => AppBar(
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(file.name, overflow: TextOverflow.ellipsis),
      FolderBadge(folder, file: file),
    ],
  ),
  bottom: note == null
      ? null
      : PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Text(note),
        ),
);
