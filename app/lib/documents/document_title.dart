import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';

/// Displayed title of a document of [type] holding [text] at [path]: its
/// own title as its type finds it, else the file name without its
/// extension.
String documentTitle(String text, RelPath path, DocumentType type) =>
    type.cardSummary(text, path).title;

/// The first line with words of [text], the content of a document of
/// [type], as plain words; empty if there is none. Names documents.
String documentTitleLine(String text, DocumentType type) =>
    type.support.summary(text, maxLines: 0).firstLine;
