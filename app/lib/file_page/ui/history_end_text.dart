import 'package:truce_core/truce_core.dart' show EditHistory, HistoryStart;

/// What the user is told when undo reaches the start of the history.
extension HistoryStartText on HistoryStart {
  String get text => switch (this) {
    HistoryStart.opened => 'Nothing more to undo since you opened the file.',
    HistoryStart.changedElsewhere =>
      'Nothing more to undo since the file was reloaded with changes from '
          'the folder.',
    HistoryStart.replacedHere =>
      'Nothing more to undo since you picked a version or dropped your edits.',
    HistoryStart.limit =>
      'Nothing more to undo: only the last ${EditHistory.limit} steps are '
          'kept.',
  };
}
