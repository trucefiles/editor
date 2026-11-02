import 'package:truce_core/truce_core.dart';

import 'file_settings.dart';
import 'file_text.dart';

/// A deleted file as last read, its text, mark and settings: enough
/// to write it back as it was.
typedef UndoableDelete = ({
  FileText file,
  String text,
  FileMark mark,
  FileSettings settings,
});
