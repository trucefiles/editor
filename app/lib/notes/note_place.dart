import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';

/// Where a note goes: a folder and one of its subfolders, `null` for the
/// folder's top level.
typedef NotePlace = ({NoteFolder folder, RelPath? subfolder});
