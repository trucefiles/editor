import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart' show CalendarSupport;
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart'
    show ExtensionFileTypeDetector, FileTypeDetector;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_image_file/truce_image_file.dart' show ImageFileSupport;
import 'package:truce_image_view/truce_image_view.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show MarkdownSupport, markdownType;
import 'package:truce_plain_text/truce_plain_text.dart' show PlainTextSupport;

import '../calendar_tab/calendar_clock.dart';
import '../common/time_texts.dart';
import '../images/images_wiring.dart';
import '../platform/platform_wiring.dart';
import 'calendar_wiring.dart';
import 'markdown_wiring.dart';

/// The file types the app handles, by their files alone (no editor, no
/// app service): what folders, backups and the types' arrivals need,
/// so they never depend on the editors' services. [fileTypesProvider]
/// gives each one its editor.
final fileTypeDetectorProvider = Provider<FileTypeDetector>(
  (_) => ExtensionFileTypeDetector.of(const [
    MarkdownSupport(),
    PlainTextSupport(),
    CalendarSupport(),
    ImageFileSupport(),
  ]),
);

/// The file types the app handles: the one place that picks them,
/// at compile time; handed down from here to whatever needs them, down to
/// what the app may touch in a folder. Each type says what new files of
/// it the user can make; a plain new file is a Markdown document.
final fileTypesProvider = Provider<ShownFileTypes<FilePageType>>((ref) {
  final markdown = MarkdownEditableType(ref.watch(markdownServicesProvider));
  final calendars = CalendarEditableType(
    day: ref.watch(timeTextsProvider).day,
    deviceZone: ref.watch(deviceZoneProvider),
    starts: ref.watch(calendarStartsProvider),
    pickFile: ref.watch(calendarFilePickerProvider),
    openers: ref.watch(eventOpenersProvider),
    clock: ref.watch(calendarClockProvider),
  );
  return ShownFileTypes([
    markdown,
    const PlainTextEditableType(),
    calendars,
    ImageViewType(ref.watch(imagePickingProvider)),
  ]);
});

/// What each file type does as its files move or are restored: Markdown
/// documents take their images along; the others are written as they
/// are.
final fileArrivalsProvider = Provider<FileArrivals>(
  (ref) => FileArrivals(ref.watch(fileTypeDetectorProvider), {
    markdownType: ref.watch(markdownArrivalProvider),
  }),
);
