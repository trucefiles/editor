import 'package:truce_calendar/truce_calendar.dart';

import '../calendar_import_file.dart';

/// What the user is told of an import they asked for.
String importHint(ImportOutcome outcome) => switch (outcome) {
  FileNotRead() => "Couldn't read this file.",
  FileImported(:final report) => switch (report) {
    NotACalendar() => "This file isn't a calendar.",
    NothingToImport() => 'There are no events or tasks in this file.',
    ItemsImported(added: 0, updated: 0) => 'Everything in this file is already in the calendar.',
    ItemsImported(:final added, :final updated, :final tasks) => switch ((
      added,
      updated,
    )) {
      (_, 0) => 'Added ${_counted(added, tasks: tasks)}.',
      (0, _) => 'Updated ${_counted(updated, tasks: tasks)}.',
      _ =>
        'Added ${_counted(added, tasks: tasks, of: added + updated)} '
            'and updated $updated.',
    },
  },
};

/// [count] of what came in, [tasks] of all [of] them tasks: named events
/// or tasks when all are one kind, else entries.
String _counted(int count, {required int tasks, int? of}) {
  final all = of ?? count;
  final (one, many) = switch (tasks) {
    0 => ('event', 'events'),
    _ when tasks == all => ('task', 'tasks'),
    _ => ('entry', 'entries'),
  };
  return '$count ${count == 1 ? one : many}';
}
