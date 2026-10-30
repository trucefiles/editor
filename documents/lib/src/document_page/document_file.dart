import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../document_file_name.dart';
import '../document_place.dart';
import '../document_text.dart';
import '../document_type.dart';

/// Where an open document's file is: one that exists, or the place a new
/// document's file goes once it is created.
sealed class DocumentFile {
  const DocumentFile();

  DocumentFolder get folder;

  /// The file in [folder] for a document whose text has [summary].
  RelPath pathFor(TextSummary<Object?> summary);
}

/// The file exists, as [document] was last read or written.
final class ExistingFile extends DocumentFile {
  const ExistingFile(this.document);

  final DocumentText document;

  @override
  DocumentFolder get folder => document.folder;

  @override
  RelPath pathFor(TextSummary<Object?> summary) => document.path;
}

/// A new document of [type]: its file goes to [place], named [name], or
/// after its first line while [name] is `null`; a number is added if the
/// name is taken then. [newSubfolder]: [place]'s subfolder is a new one
/// the user asked for, made right before the file.
final class NewFile extends DocumentFile {
  const NewFile(
    this.place, {
    required this.type,
    this.name,
    this.newSubfolder = false,
  });

  final DocumentPlace place;

  final DocumentType type;

  final String? name;

  final bool newSubfolder;

  @override
  DocumentFolder get folder => place.folder;

  /// The file's name without its extension, for a document whose text
  /// has [summary].
  String titleFor(TextSummary<Object?> summary) => name ?? summary.firstLine;

  @override
  RelPath pathFor(TextSummary<Object?> summary) {
    final name = documentFileName(
      titleFor(summary),
      extension: type.newFileExtension,
    );
    return place.subfolder?.child(name) ?? RelPath.parse(name)!;
  }
}
