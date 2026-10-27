import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'note_file_name.dart';

/// Displayed title: the document's own title (see
/// [DocumentSummary.title]), else the file name without its extension.
String noteTitle(String text, RelPath path) =>
    noteTitleOf(DocumentSummary.of(text), path);

/// [noteTitle] from a [summary] already read.
String noteTitleOf(DocumentSummary summary, RelPath path) =>
    summary.title ?? splitFileName(path.name).base;

/// The first line of [text] with words, as plain words; empty if there is
/// none. Names new notes.
String noteTitleLine(String text) => DocumentSummary.of(text).firstLine;
