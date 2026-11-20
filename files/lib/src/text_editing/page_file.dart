import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_place.dart';
import '../file_text.dart';
import '../new_file_name.dart';
import '../shown_file_type.dart';

/// Where an open file is: one that exists, or the place a new
/// file goes once it is created.
sealed class PageFile {
  const PageFile();

  Folder get folder;
}

/// The file exists, as [file] was last read or written.
final class ExistingFile extends PageFile {
  const ExistingFile(this.file);

  final FileText file;

  @override
  Folder get folder => file.folder;

  /// The file in [folder].
  RelPath get path => file.path;
}

/// A new file of [type]: its file goes to [place], named [name], or
/// after its first line while [name] is `null`; a number is added if the
/// name is taken then. [newSubfolder]: [place]'s subfolder is a new one
/// the user asked for, made right before the file. It starts with
/// [start], written only with the user's first edit.
final class NewFile extends PageFile {
  const NewFile(
    this.place, {
    required this.type,
    this.start = '',
    this.name,
    this.newSubfolder = false,
  });

  final String start;

  final FilePlace place;

  final ShownFileType type;

  final String? name;

  final bool newSubfolder;

  @override
  Folder get folder => place.folder;

  /// The file's name without its extension, for a file whose text
  /// starts with [firstLine] (as its type reads it).
  String titleFor(String firstLine) => name ?? firstLine;

  /// The file in [folder] for a file whose text starts with
  /// [firstLine].
  RelPath pathFor(String firstLine) {
    final name = newFileName(
      titleFor(firstLine),
      extension: type.newFileExtension,
    );
    return place.subfolder?.child(name) ?? RelPath.parse(name)!;
  }
}
