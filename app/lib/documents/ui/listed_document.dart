import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../folder_state/folder_state_controller.dart';
import '../document.dart';
import '../document_settings.dart';
import '../document_settings_controller.dart';
import '../document_title.dart';
import '../previews/card_preview.dart';
import '../previews/card_preview_controller.dart';

/// What a listed document shows besides its listing: its [preview], read
/// once it shows, its color, its settings on this device, and whether a
/// sync conflict of it waits.
typedef ListedLook = ({
  CardPreview preview,
  DocumentMark mark,
  DocumentSettings settings,
  bool hasConflict,
});

/// [document]'s look, as it is now; rebuilds only when its own parts
/// change.
ListedLook watchListed(WidgetRef ref, Document document) {
  final key = document.key;
  return (
    preview: ref.watch(cardPreviewProvider(document)),
    mark: ref.watch(
      folderContentsProvider.select(
        (contents) => contents.value?.markOf(key) ?? DocumentMark.none,
      ),
    ),
    settings: ref.watch(
      documentSettingsProvider.select((all) => settingsIn(all.value, key)),
    ),
    hasConflict: ref.watch(
      folderContentsProvider.select(
        (contents) => contents.value?.conflicts.forNote(key) != null,
      ),
    ),
  );
}

/// The title cards show for the document at [key]: its text's own once
/// read, else its file name without its extension.
String watchTitle(WidgetRef ref, DocumentKey key) => switch (ref.watch(
  folderContentsProvider.select((contents) => contents.value?.findNote(key)),
)) {
  final document? => cardTitle(
    document,
    ref.watch(cardPreviewProvider(document)),
  ),
  null => nameTitle(key.path),
};
