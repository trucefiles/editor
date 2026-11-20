import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'page_file.dart';

/// How the name field starts when the user picks the open [file]'s place
/// and name, at [path] and with [firstLine] as its text's first line:
/// [name] is the name the file keeps, empty while a new file is named
/// after its text, so that it keeps following it; [hint] is the name an
/// empty field gives it.
({String name, String hint}) nameFieldOf(
  PageFile file,
  RelPath path,
  String firstLine,
) => (
  name: switch (file) {
    NewFile(:final name) => name ?? '',
    ExistingFile() => splitFileName(path.name).base,
  },
  hint: newFileName(firstLine, extension: ''),
);
