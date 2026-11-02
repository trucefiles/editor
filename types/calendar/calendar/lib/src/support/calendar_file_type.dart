import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../health/cycle.dart';
import '../merge/calendar_merge.dart';
import '../model/calendar.dart';
import '../recurrence/occurrences.dart';
import 'calendar_summary.dart';
import 'calendar_support.dart';

/// Calendars (`.ics`), as the app shows them: cards show the name and
/// the next events, or for a health calendar the cycle; search reads the
/// name and the events' words; two versions merge event by event when
/// the user picks it. Its editor package adds how a file of it opens.
base class CalendarFileType implements ShownFileType {
  /// Cards write an event as [eventLine] and a cycle as [cycleLine]
  /// (texts are the UI's, so they come from above); [now] tells the time.
  CalendarFileType({
    required this.eventLine,
    required this.cycleLine,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String Function(Occurrence occurrence) eventLine;
  final String Function(CyclePrediction cycle, DateTime today) cycleLine;
  final DateTime Function() _now;

  @override
  CalendarSupport get support => const CalendarSupport();

  @override
  String get name => 'Calendar';

  /// iCalendar files break lines with CRLF (RFC 5545, 3.1).
  @override
  TextFile get newFile => const TextFile.empty(lineBreak: '\r\n');

  @override
  FileCardSummary cardSummary(FileText read) {
    final summary = CalendarSummary(read.text);
    final options = CalendarPreview(
      now: _now(),
      occurrenceLine: eventLine,
      cycleLine: cycleLine,
    );
    final preview = summary.preview(options);
    return FileCardSummary(
      title: titleOf(summary, read.path),
      preview: (_) => preview,
      holdsUntil: summary.holdsUntil(options),
    );
  }

  /// The calendar's name and its events' titles, places and notes, not
  /// the file's other lines.
  @override
  String searchText(FileText read) => CalendarSummary(read.text).searchText;

  @override
  TextMerge get merge => const CalendarMerge();
}

/// The new calendars the user can make, of [type] (the calendar type as
/// the app wires it): a calendar, or a health calendar, each named first.
List<NewFileChoice<T>> newCalendarChoices<T extends ShownFileType>(T type) => [
  NewFileChoice('Calendar', type, startNamed: newCalendarText),
  NewFileChoice(
    'Health calendar',
    type,
    startNamed: (name) => newCalendarText(name, health: true),
  ),
];
