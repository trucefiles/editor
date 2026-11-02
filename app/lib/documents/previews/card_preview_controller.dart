import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../file_types/document_types.dart';
import '../documents_wiring.dart';

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
/// dropped from the reads waiting once it goes away. While a new version
/// is read, the card shows the version read before. Read again while it
/// shows once its type says the preview no longer holds (e.g. a
/// calendar's next event has passed).
class CardPreviewController extends Notifier<CardPreview> {
  CardPreviewController(this.document);

  final Document document;

  @override
  CardPreview build() {
    final previews = ref.watch(cardPreviewsProvider);
    if (previews.known(document) case final preview?) {
      _readAgainOnceStale(previews, preview);
      return preview;
    }
    ref.onDispose(() => previews.drop(document));
    unawaited(
      previews.read(document).then((preview) {
        if (!ref.mounted) return;
        _readAgainOnceStale(previews, preview);
        state = preview;
      }),
    );
    return previews.lastKnown(document) ?? const PreviewReading();
  }

  void _readAgainOnceStale(CardPreviews previews, CardPreview preview) {
    if (previews.holdsFor(preview) case final left?) {
      final stale = Timer(left, ref.invalidateSelf);
      ref.onDispose(stale.cancel);
    }
  }
}
