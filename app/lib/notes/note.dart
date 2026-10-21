import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import 'note_summary.dart';

/// One note file, as last read.
@immutable
final class Note {
  Note({
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

  /// Worked out once, on first use, from [file].
  late final NoteSummary _summary = NoteSummary.of(file.text, path);

  String get title => _summary.title;

  /// The preview of the note's text for its card; see [NoteSummary].
  String preview({required bool hideDone}) =>
      _summary.previewOf(hideDone: hideDone);

  /// This note with [folder]'s current name and color; itself if they are
  /// unchanged.
  Note inFolder(NoteFolder folder) => folder == this.folder
      ? this
      : Note(
          folder: folder,
          path: path,
          file: file,
          version: version,
          modified: modified,
        );
}

/// Identifies a note across rescans.
typedef NoteKey = ({String folderId, RelPath path});
