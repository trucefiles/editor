import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../common/time_texts.dart';
import 'editable_type.dart';

/// Calendars (`.ics`): cards show the name and the next events, or for a
/// health calendar the cycle; two versions merge event by event when the
/// user picks it; shown on the calendar page.
final class CalendarFileType implements EditableType {
  /// [times] writes the days on cards; [deviceZone] tells this device's
  /// time zone, for new events; [viewChoice] the view calendars open in;
  /// [now] tells the time.
  CalendarFileType({
    required this.times,
    required this.deviceZone,
    required this.viewChoice,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimeTexts times;
  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;
  final DateTime Function() _now;

  /// The new calendars the user can make.
  List<NewFileChoice<EditableType>> get newFileChoices => [
    NewFileChoice('Calendar', this, startNamed: newCalendarText),
    NewFileChoice(
      'Health calendar',
      this,
      startNamed: (name) => newCalendarText(name, health: true),
    ),
  ];

  @override
  CalendarSupport get support => const CalendarSupport();

  @override
  String get newFileExtension => '.ics';

  /// iCalendar files break lines with CRLF (RFC 5545, 3.1).
  @override
  TextFile get newFile => const TextFile.empty(lineBreak: '\r\n');

  @override
  FileCardSummary cardSummary(FileText read) {
    final summary = CalendarSummary(read.text);
    final options = CalendarPreview(
      now: _now(),
      occurrenceLine: (occurrence) =>
          '${times.day(occurrence.start, allDay: occurrence.allDay)}  '
          '${occurrence.part.summary.trim()}',
      cycleLine: cycleText,
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
