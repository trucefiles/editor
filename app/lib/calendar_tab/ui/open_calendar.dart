import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_files/truce_files.dart';

import '../../file_types/calendar_wiring.dart';
import '../../files/ui/open_file.dart';

/// Opens the calendar [file], its page starting with [start] once its
/// calendar shows; what it didn't take is dropped once the page is left
/// (or didn't open), so a later open doesn't start it.
Future<void> openCalendar(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
  CalendarStart start,
) async {
  final starts = ref.read(calendarStartsProvider)..ask(file.key, start);
  try {
    await openFile(context, ref, file);
  } finally {
    starts.forget(file.key);
  }
}
