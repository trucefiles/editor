import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../text/text_summary.dart';

/// The displayed title of the file at [path] with [summary]: the
/// text's own, else the file name without its extension.
String titleOf(TextSummary<Object?> summary, RelPath path) =>
    ownTitleOr(summary.title, path);
