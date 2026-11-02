import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import 'calendar_editor_part.dart';
import 'calendar_editor_view.dart';
import 'ui/cycle_text.dart';
import 'ui/occurrence_texts.dart';

/// Calendars, shown on the calendar page; cards write their events'
/// days as [DayText] says and their titles as the calendar page does.
final class CalendarEditableType extends CalendarFileType
    implements EditableType {
  /// [day] writes an event's day on cards; [deviceZone] tells this
  /// device's time zone, for new events; [viewChoice] the view calendars
  /// open in; [now] tells the time.
  CalendarEditableType({
    required DayText day,
    required this.deviceZone,
    required this.viewChoice,
    super.now,
  }) : super(
         occurrenceLine: (occurrence) => occurrenceLine(occurrence, day),
         cycleLine: cycleText,
       );

  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = CalendarEditorPart(start);
    return (
      part: part,
      view: CalendarEditorView(
        part,
        deviceZone: deviceZone,
        viewChoice: viewChoice,
      ),
    );
  }
}
