import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../folders/folder_selection.dart';
import 'file_type_selection.dart';
import 'home_view.dart';

/// Shows All files filtered to [file]'s folder, letting its type
/// through, so the user finds it there (e.g. a new image they just
/// added). Read through [container], as the page that asks may be gone.
void showInAllFiles(ProviderContainer container, ListedFile file) {
  container.read(homeViewProvider.notifier).show(HomeView.all);
  container.read(pickedFoldersProvider.notifier).only(file.folder.id);
  container.read(pickedFileTypesProvider.notifier).reveal(file.type.type);
}
