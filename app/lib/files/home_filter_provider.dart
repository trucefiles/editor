import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../folders/folder_selection.dart';
import 'file_type_selection.dart';

/// Which files home and All show: the folders and the file types picked.
final homeFilterProvider = Provider<HomeFilter>(
  (ref) => HomeFilter(
    folders: ref.watch(pickedFoldersProvider),
    types: ref.watch(pickedFileTypesProvider),
  ),
);
