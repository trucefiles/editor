import 'package:truce_core/truce_core.dart';

import '../documents/document_file_name.dart';
import '../documents/document_place.dart';
import '../documents/document_text.dart';
import '../documents/document_title.dart';
import '../file_types/document_type.dart';
import '../folders/document_folder.dart';

/// Where an open document's file is: one that exists, or the place a new
/// document's file goes once it is created.
sealed class DocumentFile {
  const DocumentFile();

  DocumentFolder get folder;

  DocumentType get type;

  /// The file in [folder] for a document holding [text].
  RelPath pathFor(String text);
}

/// The file exists, as [document] was last read or written.
final class ExistingFile extends DocumentFile {
  const ExistingFile(this.document);

  final DocumentText document;

  @override
  DocumentFolder get folder => document.folder;

  @override
  DocumentType get type => document.type;

  @override
  RelPath pathFor(String text) => document.path;
}

/// A new document of [type]: its file goes to [place], named [name], or
/// after its first line while [name] is `null`; a number is added if the
/// name is taken then.
final class NewFile extends DocumentFile {
  const NewFile(this.place, {required this.type, this.name});

  final DocumentPlace place;

  @override
  final DocumentType type;

  final String? name;

  @override
  DocumentFolder get folder => place.folder;

  /// The file's name without its extension, for a document holding
  /// [text].
  String titleFor(String text) => name ?? documentTitleLine(text, type);

  @override
  RelPath pathFor(String text) {
    final name = documentFileName(
      titleFor(text),
      extension: type.newFileExtension,
    );
    return place.subfolder?.child(name) ?? RelPath.parse(name)!;
  }
}
