import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

/// Where a file goes: a folder and a subfolder in it, `null` for the
/// folder's top level.
typedef FilePlace = ({Folder folder, RelPath? subfolder});

/// The top level of [folder].
FilePlace topOf(Folder folder) => (folder: folder, subfolder: null);
