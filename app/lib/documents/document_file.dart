import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import '../notes/note.dart';
import '../notes/note_file_name.dart';
import '../notes/note_place.dart';
import '../notes/note_title.dart';

/// Where an open document's file is: one that exists, or the place a new
/// document's file goes once it is created.
sealed class DocumentFile {
  const DocumentFile();

  NoteFolder get folder;

  /// The file in [folder] for a document holding [text].
  RelPath pathFor(String text);
}

/// The file exists, as [note] was last read or written.
final class ExistingFile extends DocumentFile {
  const ExistingFile(this.note);

  final Note note;

  @override
  NoteFolder get folder => note.folder;

  @override
  RelPath pathFor(String text) => note.path;
}

/// A new document's file goes to [place], named [name], or after its
/// first line while [name] is `null`; a number is added if the name is
/// taken then.
final class NewFile extends DocumentFile {
  const NewFile(this.place, {this.name});

  final NotePlace place;
  final String? name;

  @override
  NoteFolder get folder => place.folder;

  /// The file's name without its extension, for a document holding
  /// [text].
  String titleFor(String text) => name ?? noteTitleLine(text);

  @override
  RelPath pathFor(String text) {
    final name = noteFileName(titleFor(text));
    return place.subfolder?.child(name) ?? RelPath.parse(name)!;
  }
}
