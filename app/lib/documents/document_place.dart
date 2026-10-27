import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';

/// Where a document goes: a folder and one of its subfolders, `null` for the
/// folder's top level.
typedef DocumentPlace = ({DocumentFolder folder, RelPath? subfolder});
