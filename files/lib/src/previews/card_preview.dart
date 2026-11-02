import 'package:truce_core/truce_core.dart';

import '../file_card_summary.dart';
import '../file_title.dart';
import '../files_of_folder.dart';
import '../listed_file.dart';
import '../open_failure.dart';
import '../shown_file_types.dart';

/// What a card shows of a file's text.
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

  final FileCardSummary summary;
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

/// The title a card shows for [file] with [preview]: the text's own,
/// else the file name without its extension.
String cardTitle(ListedFile file, CardPreview preview) => switch (preview) {
  Previewed(:final summary) => summary.title,
  PreviewReading() ||
  PreviewNotText() ||
  PreviewUnreadable() => nameTitle(file.path),
};

/// [file]'s preview, read from its file in [files] and worked out by
/// its type in [types]; never throws.
Future<CardPreview> readPreview(
  ListedFile file,
  FolderFiles files,
  ShownFileTypes types,
) async => switch (await files.of(file.folder).reload(file)) {
  Ok(value: final read) => Previewed(types.ofFile(read.type).cardSummary(read)),
  Err(error: NotText()) => const PreviewNotText(),
  Err(error: NotRead()) => const PreviewUnreadable(),
};
