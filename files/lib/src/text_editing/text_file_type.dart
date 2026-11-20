import 'package:truce_core/truce_core.dart';

import '../file_bytes.dart';
import '../file_card_summary.dart';
import '../file_merge.dart';
import '../file_title.dart';
import '../new_file_choice.dart';
import '../shown_file_type.dart';
import 'file_text.dart';
import 'text_bytes_merge.dart';

/// A file type whose files are text: read, edited and written by the
/// text editing kit. A type says what its card, search and merge make of
/// the text; reading the bytes as text is built in, and only a file that
/// is text shows or merges.
///
/// Not `base`: a type's page side (e.g. `EditableType`) is an interface
/// that implements it.
abstract class TextFileType implements ShownFileType {
  const TextFileType();

  /// The byte style of a new file of this type (e.g. its line breaks).
  TextFile get newFile;

  /// What lists show of [text], with previews of up to [maxLines] lines.
  TextSummary<Object?> summary(String text, {required int maxLines});

  /// What the card of [read] shows.
  FileCardSummary textCard(FileText read);

  /// The words a search finds in [read] (e.g. its whole text, or only
  /// what shows of it).
  String textSearchWords(FileText read);

  /// How two texts of this type merge into one when the user picks it;
  /// `null` if they don't.
  TextMerge? get textMerge;

  @override
  FileCardSummary? cardSummary(FileBytes read) => switch (FileText.of(read)) {
    final text? => textCard(text),
    null => null,
  };

  /// Titled as its card is.
  @override
  SearchText? searchText(FileBytes read) => switch (FileText.of(read)) {
    final text? => (
      title: titleOf(
        summary(text.text, maxLines: FileCardSummary.previewLines),
        text.path,
      ),
      text: textSearchWords(text),
    ),
    null => null,
  };

  @override
  FileMerge? get merge => switch (textMerge) {
    final merge? => TextBytesMerge(merge),
    null => null,
  };
}

/// What a new text file starts with: [text].
final class TextStart implements NewFileStart {
  const TextStart(this.text);

  final String text;
}

/// What a text type's new file starts with.
extension NewTextStart on NewFileKind {
  /// The text a new file of this kind opens with; empty if its type gave
  /// none. A start that isn't text is a bug in the type.
  String get startText => switch (start) {
    null => '',
    TextStart(:final text) => text,
    final other => throw StateError('$other is no text start'),
  };
}
