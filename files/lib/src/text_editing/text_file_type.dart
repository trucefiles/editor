import 'package:truce_core/truce_core.dart';

import '../file_bytes.dart';
import '../file_card_summary.dart';
import '../file_merge.dart';
import '../file_text.dart';
import '../file_title.dart';
import '../new_file_choice.dart';
import '../shown_file_type.dart';
import 'text_bytes_merge.dart';

/// A file type whose files are text: read, edited and written by the
/// text editing kit. Its card, search and merge work on the text; the
/// bytes side comes from [TextTypeBytes].
abstract interface class TextFileType implements ShownFileType {
  /// The byte style of a new file of this type (e.g. its line breaks).
  TextFile get newFile;

  /// What lists show of [text], with previews of up to [maxLines] lines.
  TextSummary<Object?> summary(String text, {required int maxLines});

  /// What cards show of [read], from its summary.
  FileCardSummary cardSummaryOf(FileText read);

  /// The words a search finds in [read] (e.g. its whole text, or only
  /// what shows of it).
  String searchTextOf(FileText read);

  /// How two texts of this type merge into one when the user picks it;
  /// `null` if they don't.
  TextMerge? get textMerge;
}

/// A text type's side on bytes: a file is read as text, and only a
/// file that is text shows or merges.
mixin TextTypeBytes implements TextFileType {
  @override
  FileCardSummary? cardSummary(FileBytes read) => switch (FileText.of(read)) {
    final text? => cardSummaryOf(text),
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
      text: searchTextOf(text),
    ),
    null => null,
  };

  @override
  FileMerge? get merge => switch (textMerge) {
    final merge? => TextBytesMerge(merge),
    null => null,
  };
}

/// What a text type's new file starts with.
extension NewTextStart on NewFileKind {
  /// The text a new file of this kind opens with; empty if its type gave
  /// none.
  String get startText => switch (start) {
    final String text => text,
    _ => '',
  };
}
