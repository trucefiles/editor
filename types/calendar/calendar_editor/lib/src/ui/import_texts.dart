import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import '../calendar_import_file.dart';

/// What the user is told of an import they asked for.
String importHint(ImportOutcome outcome) => switch (outcome) {
  FileNotRead() => "Couldn't read this file.",
  FileImported(:final report) => switch (report) {
    NotACalendar() => "This file isn't a calendar.",
    NoEvents() => 'There are no events in this file.',
    EventsImported(added: 0, updated: 0, kept: [], deletedHere: []) =>
      'These events are already in the calendar.',
    EventsImported(
      :final added,
      :final updated,
      :final kept,
      :final deletedHere,
    ) =>
      [
        ?_changed(added, updated),
        if (kept.isNotEmpty)
          'Kept your newer ${kept.length == 1 ? 'version' : 'versions'} '
              'of ${fewNamed(kept)}.',
        if (deletedHere.isNotEmpty)
          '${fewNamed(deletedHere)} '
              '${deletedHere.length == 1 ? 'was' : 'were'} deleted here, so '
              '${deletedHere.length == 1 ? 'it stays' : 'they stay'} deleted.',
      ].join(' '),
  },
};

/// How many events an import added and updated; `null` if none.
String? _changed(int added, int updated) => switch ((added, updated)) {
  (0, 0) => null,
  (_, 0) => 'Added ${_events(added)}.',
  (0, _) => 'Updated ${_events(updated)}.',
  _ => 'Added ${_events(added)} and updated $updated.',
};

String _events(int count) => '$count ${count == 1 ? 'event' : 'events'}';
