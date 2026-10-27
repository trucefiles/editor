import 'package:truce_core/truce_core.dart';

import '../notes/note.dart';

/// A version of a note's file as the app read or wrote it: owners only
/// compare it; the app acts on its [note] (where the file is, how it is
/// written).
final class NoteVersion extends Version {
  NoteVersion(this.note) : super((note.folder.id, note.path, note.version));

  final Note note;
}

extension NoteSeen on Note {
  /// This note's file as the file owner sees it: its text and version.
  Seen get seen => Seen(file.text, NoteVersion(this));
}

/// The note [version] was read or written as. Every version the app
/// hands to a file owner is a [NoteVersion].
Note noteOf(Version version) => (version as NoteVersion).note;
