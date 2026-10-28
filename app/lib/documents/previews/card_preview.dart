import '../document.dart';
import '../document_card_summary.dart';
import '../document_title.dart';

/// What a card shows of a document's text.
sealed class CardPreview {
  const CardPreview();
}

/// The text is being read.
final class PreviewReading extends CardPreview {
  const PreviewReading();
}

/// The text read, as cards show it.
final class Previewed extends CardPreview {
  const Previewed(this.summary);

  final DocumentCardSummary summary;
}

/// The text could not be read; the card shows the file name only.
final class PreviewUnreadable extends CardPreview {
  const PreviewUnreadable();
}

/// The title a card shows for [document] with [preview]: the text's own,
/// else the file name without its extension.
String cardTitle(Document document, CardPreview preview) => switch (preview) {
  Previewed(:final summary) => summary.title,
  PreviewReading() || PreviewUnreadable() => nameTitle(document.path),
};
