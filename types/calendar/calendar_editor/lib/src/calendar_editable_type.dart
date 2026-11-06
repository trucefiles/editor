import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import 'calendar_editor_part.dart';
import 'calendar_editor_view.dart';
import 'calendar_import_file.dart';
import 'calendar_start.dart';
import 'ui/cycle_text.dart';
import 'ui/occurrence_texts.dart';

/// Calendars, shown on the calendar page; cards write their events'
/// days as [DayText] says and their titles as the calendar page does.
final class CalendarEditableType extends CalendarFileType
    implements EditableType {
  /// [day] writes an event's day on cards; [deviceZone] tells this
  /// device's time zone, for new events; [viewChoice] the view calendars
  /// open in; [starts] what calendar pages are asked to start with;
  /// [pickFile] asks for a calendar file to import; [now] tells the time.
  CalendarEditableType({
    required DayText day,
    required this.deviceZone,
    required this.viewChoice,
    required this.starts,
    required this.pickFile,
    super.now,
  }) : super(
         eventLine: (occurrence) => occurrenceLine(occurrence, day),
         cycleLine: cycleText,
       );

  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;
  final CalendarStarts starts;
  final PickCalendarFile pickFile;

  @override
  IconData get icon => Icons.calendar_month_outlined;

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = CalendarEditorPart(start, pickFile: pickFile);
    return (
      part: part,
      view: CalendarEditorView(
        part,
        deviceZone: deviceZone,
        viewChoice: viewChoice,
        starts: starts,
      ),
    );
  }
}
