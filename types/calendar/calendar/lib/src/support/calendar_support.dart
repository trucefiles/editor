import 'package:truce_core/truce_core.dart';

import 'calendar_summary.dart';

/// Calendar files.
const calendarType = FileType('calendar');

/// What the app knows of calendar files: `.ics`, and what lists show of
/// one ([CalendarSummary]).
final class CalendarSupport implements FileTypeSupport<CalendarPreview> {
  const CalendarSupport();

  @override
  FileType get type => calendarType;

  @override
  Set<String> get extensions => const {'ics'};

  /// [maxLines] is the preview's [CalendarPreview.count] instead.
  @override
  CalendarSummary summary(String text, {required int maxLines}) =>
      CalendarSummary(text);
}
