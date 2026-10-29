import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../file_types/document_types.dart';
import '../document.dart';
import '../documents_wiring.dart';
import 'card_preview.dart';
import 'card_previews.dart';

/// The app's card previews: each read from the document's file and worked
/// out by its type.
final cardPreviewsProvider = Provider<CardPreviews>((ref) {
  final files = ref.watch(folderFilesProvider);
  final types = ref.watch(documentTypesProvider);
  return CardPreviews((document) => readPreview(document, files, types));
});

final cardPreviewProvider = NotifierProvider.autoDispose
    .family<CardPreviewController, CardPreview, Document>(
      CardPreviewController.new,
    );

/// What one card shows of its document's text: read once the card shows,
/// dropped from the reads waiting once it goes away.
class CardPreviewController extends Notifier<CardPreview> {
  CardPreviewController(this.document);

  final Document document;

  @override
  CardPreview build() {
    final previews = ref.watch(cardPreviewsProvider);
    if (previews.known(document) case final preview?) return preview;
    ref.onDispose(() => previews.drop(document));
    unawaited(
      previews.read(document).then((preview) {
        if (ref.mounted) state = preview;
      }),
    );
    return const PreviewReading();
  }
}
