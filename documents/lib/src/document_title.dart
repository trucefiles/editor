import 'package:truce_core/truce_core.dart';

import 'document_file_name.dart';

/// The displayed title of the document at [path] with [summary]: the
/// text's own, else the file name without its extension.
String titleOf(TextSummary<Object?> summary, RelPath path) =>
    summary.title ?? nameTitle(path);

/// The title of the document at [path] from its name only, while its text
/// is not read: the file name without its extension.
String nameTitle(RelPath path) => splitFileName(path.name).base;
