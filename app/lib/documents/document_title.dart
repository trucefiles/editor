import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import 'document_file_name.dart';

/// Displayed title of a document of [type] holding [text] at [path]: its
/// own title as its type finds it, else the file name without its
/// extension.
String documentTitle(String text, RelPath path, DocumentType type) =>
    titleOf(type.support.summary(text, maxLines: 0), path);

/// The displayed title of the document at [path] with [summary]: the
/// text's own, else the file name without its extension.
String titleOf(TextSummary<Object?> summary, RelPath path) =>
    summary.title ?? nameTitle(path);

/// The title of the document at [path] from its name only, while its text
/// is not read: the file name without its extension.
String nameTitle(RelPath path) => splitFileName(path.name).base;

/// The first line with words of [text], the content of a document of
/// [type], as plain words; empty if there is none. Names documents.
String documentTitleLine(String text, DocumentType type) =>
    type.support.summary(text, maxLines: 0).firstLine;
