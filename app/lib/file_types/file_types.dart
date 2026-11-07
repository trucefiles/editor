import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import '../common/time_texts.dart';
import '../platform/platform_wiring.dart';
import 'calendar_wiring.dart';
import 'markdown_wiring.dart';

/// The file types the app handles: the one place that picks them,
/// at compile time; handed down from here to whatever needs them, down to
/// what the app may touch in a folder. Each type says what new files of
/// it the user can make; a plain new file is a Markdown document.
final fileTypesProvider = Provider<ShownFileTypes<EditableType>>((ref) {
  final markdown = MarkdownEditableType(ref.watch(markdownServicesProvider));
  final calendars = CalendarEditableType(
    day: ref.watch(timeTextsProvider).day,
    deviceZone: ref.watch(deviceZoneProvider),
    starts: ref.watch(calendarStartsProvider),
    pickFile: ref.watch(calendarFilePickerProvider),
  );
  return ShownFileTypes([markdown, const PlainTextEditableType(), calendars]);
});
