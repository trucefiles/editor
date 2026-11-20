import 'package:truce_core/truce_core.dart';

/// Calendar files.
const calendarType = FileType('calendar');

/// What the app knows of calendar files: `.ics`.
final class CalendarSupport implements FileTypeSupport {
  const CalendarSupport();

  @override
  FileType get type => calendarType;

  @override
  Set<String> get extensions => const {'ics'};
}
