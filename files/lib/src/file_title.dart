import 'package:truce_core/truce_core.dart';

import 'new_file_name.dart';

/// The displayed title of the file at [path] with [summary]: the
/// text's own, else the file name without its extension.
String titleOf(TextSummary<Object?> summary, RelPath path) =>
    ownTitleOr(summary.title, path);

/// The displayed title of the file at [path] whose text gives it [own]:
/// that, else the file name without its extension.
String ownTitleOr(String? own, RelPath path) => own ?? nameTitle(path);

/// The title of the file at [path] from its name only, while its text
/// is not read: the file name without its extension.
String nameTitle(RelPath path) => splitFileName(path.name).base;
