import 'package:truce_core/truce_core.dart';

import '../file_types/document_types.dart';

/// Displayed title of a document holding [text] at [path]: its own title
/// as its type finds it, else the file name without its extension.
String documentTitle(String text, RelPath path) =>
    documentTypes.of(path).cardSummary(text, path).title;

/// The first line of [text] with words, as plain words; empty if there is
/// none. Names new documents.
String documentTitleLine(String text) =>
    newDocumentType.support.summary(text, maxLines: 0).firstLine;
