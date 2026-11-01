import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../file_types/document_types.dart';
import '../documents_wiring.dart';

/// What a card shows a preview of: a listed [document] in its [version]
/// with the copies read into it, so a new copy is read again.
typedef PreviewKey = ({Document document, Version version});

/// The app's card previews: each read from the document's file and worked
/// out by its type.
final cardPreviewsProvider = Provider<CardPreviews<PreviewKey>>((ref) {
  final files = ref.watch(folderFilesProvider);
  final types = ref.watch(documentTypesProvider);
  return CardPreviews((key) => readPreview(key.document, files, types));
});

final cardPreviewProvider = NotifierProvider.autoDispose
    .family<CardPreviewController, CardPreview, PreviewKey>(
      CardPreviewController.new,
    );

/// What one card shows of its document's text: read once the card shows,
/// dropped from the reads waiting once it goes away; read again while it
/// shows once its type says the preview no longer holds (e.g. a
/// calendar's next event has passed).
class CardPreviewController extends Notifier<CardPreview> {
  CardPreviewController(this.document);

  final PreviewKey document;

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
    return const PreviewReading();
  }

  void _readAgainOnceStale(
    CardPreviews<PreviewKey> previews,
    CardPreview preview,
  ) {
    if (previews.holdsFor(preview) case final left?) {
      final stale = Timer(left, ref.invalidateSelf);
      ref.onDispose(stale.cancel);
    }
  }
}
