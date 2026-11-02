import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../folder_state/folder_state_controller.dart';
import '../file_settings_controller.dart';
import '../previews/card_preview_controller.dart';

/// What a listed file shows besides its listing: its [preview], read
/// once it shows, its color, its settings on this device, and whether a
/// sync conflict of it waits.
typedef ListedLook = ({
  CardPreview preview,
  FileMark mark,
  FileSettings settings,
  bool hasConflict,
});

/// [file]'s look, as it is now; rebuilds only when its own parts
/// change.
ListedLook watchListed(WidgetRef ref, ListedFile file) {
  final key = file.key;
  return (
    preview: ref.watch(cardPreviewProvider(file)),
    mark: ref.watch(
      folderContentsProvider.select(
        (contents) => contents.value?.markOf(key) ?? FileMark.none,
      ),
    ),
    settings: ref.watch(
      fileSettingsProvider.select((all) => settingsIn(all.value, key)),
    ),
    hasConflict: ref.watch(
      folderContentsProvider.select(
        (contents) => contents.value?.conflicts.forFile(key) != null,
      ),
    ),
  );
}

/// The title cards show for the file at [key]: its text's own once
/// read, else its file name without its extension.
String watchTitle(WidgetRef ref, FileKey key) => switch (ref.watch(
  folderContentsProvider.select((contents) => contents.value?.findFile(key)),
)) {
  final file? => cardTitle(file, ref.watch(cardPreviewProvider(file))),
  null => nameTitle(key.path),
};
