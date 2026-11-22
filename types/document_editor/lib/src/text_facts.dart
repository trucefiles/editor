import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

/// What the File info panel tells of a document's [kept] text: its lines
/// and words as written, so every mode tells the same.
List<FileFact> textFacts(String kept) => switch (textCounts(kept)) {
  (:final lines, :final words) => [
    TextFact('Lines', '$lines'),
    TextFact('Words', '$words'),
  ],
};
