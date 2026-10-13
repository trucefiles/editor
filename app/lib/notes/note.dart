import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import 'note_title.dart';

/// One note file, as last read.
@immutable
final class Note {
  const Note({
    required this.folder,
    required this.path,
    required this.file,
    required this.version,
    required this.modified,
  });

  final NoteFolder folder;
  final RelPath path;
  final TextFile file;

  /// Version on disk that [file] was read from or written as.
  final FileVersion version;

  /// When the file was last changed, for sorting.
  final DateTime modified;

  NoteKey get key => (folderId: folder.id, path: path);

  String get title => noteTitle(file.text, path);
}

/// Identifies a note across rescans.
typedef NoteKey = ({String folderId, RelPath path});
