import 'package:truce_core/truce_core.dart' show HistoryStart;

/// What the user is told when undo reaches the start of the history.
extension HistoryStartText on HistoryStart {
  String get text => switch (this) {
    HistoryStart.opened => 'This is how the file was when you opened it.',
    HistoryStart.changedElsewhere => 'Here the file changed elsewhere.',
    HistoryStart.replacedHere =>
      'Here a version was picked or edits were dropped.',
    HistoryStart.limit => "Older steps aren't kept.",
  };
}
