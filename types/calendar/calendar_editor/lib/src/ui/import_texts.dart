import 'package:truce_calendar/truce_calendar.dart';

import '../calendar_import_file.dart';

/// What the user is told of an import they asked for.
String importHint(ImportOutcome outcome) => switch (outcome) {
  FileNotRead() => "Couldn't read this file.",
  FileImported(:final report) => switch (report) {
    NotACalendar() => "This file isn't a calendar.",
    NoEvents() => 'There are no events in this file.',
    EventsImported(added: 0, updated: 0) =>
      'These events are already in the calendar.',
    EventsImported(:final added, :final updated) => switch ((added, updated)) {
      (_, 0) => 'Added ${_events(added)}.',
      (0, _) => 'Updated ${_events(updated)}.',
      _ => 'Added ${_events(added)} and updated $updated.',
    },
  },
};

String _events(int count) => '$count ${count == 1 ? 'event' : 'events'}';
