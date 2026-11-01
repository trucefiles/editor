import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../common/time_texts.dart';
import 'editable_type.dart';

/// Calendars (`.ics`): cards show the name and the next events, or for a
/// health calendar the cycle; texts merge event by event on their own;
/// shown on the calendar page.
final class CalendarDocumentType implements EditableType {
  /// [times] writes the days on cards; [now] tells the time.
  CalendarDocumentType({required this.times, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TimeTexts times;
  final DateTime Function() _now;

  /// The new calendars the user can make.
  List<NewDocument<EditableType>> get newDocuments => [
    NewDocument('Calendar', this, startNamed: newCalendarText),
    NewDocument(
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
  DocumentCardSummary cardSummary(DocumentText read) {
    final summary = CalendarSummary(read.text);
    final options = CalendarPreview(
      now: _now(),
      occurrenceLine: (occurrence) =>
          '${times.day(occurrence.start, allDay: occurrence.allDay)}  '
          '${occurrence.part.summary.trim()}',
      cycleLine: cycleText,
    );
    final preview = summary.preview(options);
    return DocumentCardSummary(
      title: titleOf(summary, read.path),
      preview: (_) => preview,
      holdsUntil: summary.holdsUntil(options),
    );
  }

  @override
  TextMerge get merge => const CalendarMerge();

  @override
  OpenedEditor openEditor(EditorStart start, EditorPage page) {
    final part = CalendarEditorPart(start);
    return (part: part, view: CalendarEditorView(part));
  }
}
