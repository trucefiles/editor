import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import 'calendar_clock.dart';
import 'calendar_editor_part.dart';
import 'calendar_editor_view.dart';
import 'calendar_import_file.dart';
import 'calendar_start.dart';
import 'ui/cycle_text.dart';
import 'ui/event_links.dart';
import 'ui/occurrence_texts.dart';

/// Calendars, shown on the calendar page; cards write their events'
/// days as [DayText] says and their titles as the calendar page does.
final class CalendarEditableType extends CalendarFileType
    implements EditableType {
  /// [day] writes an event's day on cards; [deviceZone] tells this
  /// device's time zone, for new events; [starts] what calendar pages are
  /// asked to start with;
  /// [pickFile] asks for a calendar file to import; [openers] open the
  /// links and places events name; [clock] is the calendars' clock, held
  /// by the app.
  CalendarEditableType({
    required DayText day,
    required this.deviceZone,
    required this.starts,
    required this.pickFile,
    required this.openers,
    required this.clock,
  }) : super(
         now: clock.now,
         eventLine: (occurrence) => occurrenceLine(occurrence, day),
         cycleLine: cycleText,
       );

  final DeviceZone deviceZone;
  final CalendarStarts starts;
  final PickCalendarFile pickFile;
  final EventOpeners openers;
  final CalendarClock clock;

  @override
  IconData get icon => Icons.calendar_month_outlined;

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = CalendarEditorPart(start, page, pickFile: pickFile);
    return (
      part: part,
      view: CalendarEditorView(
        part,
        deviceZone: deviceZone,
        starts: starts,
        openers: openers,
        clock: clock,
      ),
    );
  }
}
