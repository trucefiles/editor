import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

const _named =
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nX-WR-CALNAME:Trips\r\n'
    'END:VCALENDAR\r\n';

FileBytes _file(List<int> bytes) => FileBytes(
  ListedFile(
    folder: Folder(
      id: folderId('home'),
      name: 'Home',
      color: 'teal',
      location: 'home',
    ),
    path: path('trips.ics'),
    type: const CalendarSupport(),
    version: const FileVersion(0),
    modified: DateTime(2000),
    size: 0,
  ),
  Uint8List.fromList(bytes),
);

void main() {
  test('a calendar file is read whole, titled by its name', () {
    final read = readCalendar(_file(utf8.encode(_named)))!;

    expect(read.title, 'Trips');
    expect(read.calendar!.name, 'Trips');
    expect(readCalendarTitle(_file(utf8.encode(_named))), 'Trips');
  });

  test('a file that is no text or no calendar reads as none', () {
    for (final bytes in [
      [0xff, 0xfe],
      utf8.encode('just words'),
    ]) {
      expect(readCalendar(_file(bytes)), isNull);
      expect(readCalendarTitle(_file(bytes)), isNull);
    }
  });
}
