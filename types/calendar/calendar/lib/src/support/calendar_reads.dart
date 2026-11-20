import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../model/calendar.dart';
import '../model/calendar_head.dart';
import 'calendar_summary.dart';

/// A calendar file as read for a list of calendars: its [calendar],
/// `null` if only its name could be read, and its [title].
typedef ReadCalendar = ({Calendar? calendar, String title});

/// The calendar file [read]: whole, else by its name alone; `null` if it
/// is no calendar.
ReadCalendar? readCalendar(FileBytes read) {
  final text = FileText.of(read)?.text;
  if (text == null) return null;
  final summary = CalendarSummary(text);
  return switch (summary.calendar) {
    final calendar? => (calendar: calendar, title: titleOf(summary, read.path)),
    null => switch (_titleOf(text, read.path)) {
      final title? => (calendar: null, title: title),
      null => null,
    },
  };
}

/// The title of the calendar file [read], from its head alone (no
/// events); `null` if it is no calendar.
String? readCalendarTitle(FileBytes read) => switch (FileText.of(read)) {
  final text? => _titleOf(text.text, read.path),
  null => null,
};

/// The title of the calendar [text] at [path], from its head alone.
String? _titleOf(String text, RelPath path) =>
    switch (CalendarHead.read(text)) {
      final head? => ownTitleOr(calendarTitle(head), path),
      null => null,
    };
