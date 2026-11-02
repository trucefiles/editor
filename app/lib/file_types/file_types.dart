import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../common/time_texts.dart';
import '../platform/platform_wiring.dart';
import '../settings/calendar_view_setting.dart';
import 'calendar_file_type.dart';
import 'editable_type.dart';
import 'markdown_file_type.dart';
import 'plain_text_file_type.dart';

/// The file types the app handles: the one place that picks them,
/// at compile time; handed down from here to whatever needs them, down to
/// what the app may touch in a folder. A plain new file is a Markdown
/// note; calendars are made named.
final fileTypesProvider = Provider<ShownFileTypes<EditableType>>((ref) {
  final system = PlatformDispatcher.instance;
  final calendars = CalendarFileType(
    times: TimeTexts(
      locale: system.locale.toLanguageTag(),
      use24Hour: system.alwaysUse24HourFormat,
    ),
    deviceZone: ref.watch(deviceZoneProvider),
    viewChoice: ref.watch(calendarViewChoiceProvider),
  );
  return ShownFileTypes(
    [const MarkdownFileType(), const PlainTextFileType(), calendars],
    newFileChoices: [
      const NewFileChoice('Note', MarkdownFileType()),
      ...calendars.newFileChoices,
    ],
  );
});
