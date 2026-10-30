import 'package:truce_core/truce_core.dart';

import '../document.dart';
import '../document_card_summary.dart';
import '../document_files.dart';
import '../document_title.dart';
import '../document_types.dart';
import '../open_failure.dart';

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

/// The file holds no text; the card shows the file name and says so.
/// Told by the file itself, so kept like a preview.
final class PreviewNotText extends CardPreview {
  const PreviewNotText();
}

/// The file could not be read now; the card shows the file name only.
final class PreviewUnreadable extends CardPreview {
  const PreviewUnreadable();
}

/// The title a card shows for [document] with [preview]: the text's own,
/// else the file name without its extension.
String cardTitle(Document document, CardPreview preview) => switch (preview) {
  Previewed(:final summary) => summary.title,
  PreviewReading() ||
  PreviewNotText() ||
  PreviewUnreadable() => nameTitle(document.path),
};

/// [document]'s preview, read from its file in [files] and worked out by
/// its type in [types]; never throws.
Future<CardPreview> readPreview(
  Document document,
  FolderFiles files,
  DocumentTypes types,
) async => switch (await files.of(document.folder).reload(document)) {
  Ok(value: final read) => Previewed(types.ofFile(read.type).cardSummary(read)),
  Err(error: NotText()) => const PreviewNotText(),
  Err(error: NotRead()) => const PreviewUnreadable(),
};
