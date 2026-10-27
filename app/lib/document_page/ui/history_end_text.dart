import 'package:truce_markdown/truce_markdown.dart';

/// What the user is told when undo reaches the start of the history.
extension HistoryStartText on HistoryStart {
  String get text => switch (this) {
    HistoryStart.opened => 'This is how the document was when you opened it.',
    HistoryStart.changedElsewhere =>
      'Here the document changed on another device.',
    HistoryStart.replacedHere =>
      'Here a version was chosen or edits were discarded.',
    HistoryStart.limit => "Older steps aren't kept.",
  };
}
