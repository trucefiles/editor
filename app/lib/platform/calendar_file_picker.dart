import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';

/// The platform's file dialog for one calendar file (`.ics`), read
/// whole. On Linux it goes through the desktop portal; on Android it is
/// the system's file picker.
Future<Result<Uint8List?, FileNotRead>> pickCalendarFile() async {
  try {
    final file = await openFile(acceptedTypeGroups: [_calendars]);
    return Ok(await file?.readAsBytes());
  } on PlatformException {
    return const Err(FileNotRead());
  } on FileSystemException {
    return const Err(FileNotRead());
  }
}

const _calendars = XTypeGroup(
  label: 'Calendars',
  extensions: ['ics'],
  mimeTypes: ['text/calendar'],
);
