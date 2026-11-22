import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

/// What a document's [text] tells: its lines and words as written, so
/// every mode tells the same.
List<FileFact> textFacts(String text) => switch (textCounts(text)) {
  (:final lines, :final words) => [
    TextFact('Lines', '$lines'),
    TextFact('Words', '$words'),
  ],
};
