import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'file_settings.dart';
import 'listed_file.dart';

/// A deleted file as last read, its bytes, mark and settings: enough
/// to write it back as it was.
typedef UndoableDelete = ({
  ListedFile file,
  Uint8List bytes,
  FileMark mark,
  FileSettings settings,
});
