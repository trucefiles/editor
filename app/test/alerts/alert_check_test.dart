import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/alerts/alert_check_wiring.dart';
import 'package:truce_editor/alerts/alerts_wiring.dart';
import 'package:truce_editor/calendar_tab/calendar_tab_controller.dart';
import 'package:truce_editor/files/files_wiring.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';

import '../support.dart';
import 'quiet_alerts.dart';

/// A calendar named [name] with an event of that name in two hours, with
/// an alert 15 minutes before.
String _calendarWithAlert(String name) {
  String two(int n) => n.toString().padLeft(2, '0');
  final start = DateTime.now().add(const Duration(hours: 2));
  final at =
      '${start.year}${two(start.month)}${two(start.day)}'
      'T${two(start.hour)}${two(start.minute)}00';
  return 'BEGIN:VCALENDAR\nVERSION:2.0\nX-WR-CALNAME:$name\n'
      'BEGIN:VEVENT\nUID:$name\nSUMMARY:$name\nDTSTART:$at\n'
      'DURATION:PT1H\nBEGIN:VALARM\nACTION:DISPLAY\nTRIGGER:-PT15M\n'
      'END:VALARM\nEND:VEVENT\nEND:VCALENDAR\n';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppStorage storage;
  late QuietRinger ringer;

  /// The calendars read whole, by name, in order.
  late List<String> reads;

  setUp(() {
    dir = tempFolder();
    storage = AppStorage(tempFolder().path);
    // The background check runs where alerts ring with the app closed.
    ringer = QuietRinger(ringsWhileClosed: true);
    reads = [];
    File('${dir.path}/work.ics')
        .writeCreatingFolders(_calendarWithAlert('Work'));
    File('${dir.path}/home.ics')
        .writeCreatingFolders(_calendarWithAlert('Home'));
  });

  /// A fresh app wiring on the same storage, as each run of the job has.
  ProviderContainer wiring() {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        ...quietAlerts(ringer),
        calendarReadsProvider.overrideWith(
          (ref) => FileReads(
            ref.watch(fileAccessProvider),
            readAs: (read) {
              reads.add(read.path.name);
              return readCalendar(read);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The folder's files with their bytes and times.
  Map<String, (String, DateTime)> filesNow() => {
    for (final file in dir.listSync(recursive: true).whereType<File>())
      file.path: (file.readAsStringSync(), file.lastModifiedSync()),
  };

  test('rings the alerts of the calendars shown in the Calendar tab only, '
      'and writes nothing into the folders', () async {
    // The user takes Home off the tab in the app.
    final app = wiring();
    await saveFolders(app, [folderAt(dir)]);
    final tab = await app.read(calendarTabProvider.future);
    await app
        .read(calendarTabProvider.notifier)
        .place(
          tab.offered.singleWhere((each) => each.title == 'Home').file,
          TabPlace.off,
        );
    app.dispose();
    final before = filesNow();
    reads.clear();

    await alertCheckOf(wiring()).run();

    expect([for (final alert in ringer.ringing.values) alert.title], ['Work']);
    expect(reads, ['work.ics']);
    expect(filesNow(), before);
  });

  test('a second run reads no unchanged calendar', () async {
    final app = wiring();
    await saveFolders(app, [folderAt(dir)]);
    app.dispose();

    await alertCheckOf(wiring()).run();
    expect(reads, unorderedEquals(['home.ics', 'work.ics']));

    await alertCheckOf(wiring()).run();
    expect(reads, hasLength(2));
    expect(ringer.ringing, hasLength(2));
  });

  test('the app plans the shown calendars as the tab reads them', () async {
    final app = wiring();
    await saveFolders(app, [folderAt(dir)]);
    await app.read(foldersProvider.future);
    await app.read(folderContentsProvider.future);
    app.read(alertsProvider);
    final planner = app.read(alertPlannerProvider);

    await eventually(() => planner.state.planned.length == 2);
    expect(ringer.ringing, hasLength(2));
  });
}
