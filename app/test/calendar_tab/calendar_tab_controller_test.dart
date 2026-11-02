import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/calendar_tab/calendar_tab_controller.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  void write(String name, String text) =>
      File('${dir.path}/$name').writeCreatingFolders(text);

  setUp(() async {
    dir = tempFolder();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Starts the app's providers on [dir], as one folder.
  Future<void> start() async {
    await saveFolders(container, [folderAt(dir)]);
    await container.read(foldersProvider.future);
    await container.read(folderContentsProvider.future);
  }

  /// The tab's calendars as their names and whether each is shown.
  Future<List<(String, bool)>> tab() async => [
    for (final calendar in await container.read(calendarTabProvider.future))
      (calendar.calendar.name, calendar.shown),
  ];

  test('no tab without a calendar', () async {
    write('notes.md', '# Notes');
    await start();

    expect(container.read(hasCalendarsProvider), isFalse);
    expect(await tab(), isEmpty);
  });

  test('every calendar by name, shown until the user hides it; a file '
      'that is no calendar left out', () async {
    write('work.ics', newCalendarText('Work'));
    write('home.ics', newCalendarText('Home'));
    write('broken.ics', 'not a calendar');
    write('notes.md', '# Notes');
    await start();

    expect(container.read(hasCalendarsProvider), isTrue);
    expect(await tab(), [('Home', true), ('Work', true)]);

    final work = (await container.read(calendarTabProvider.future))
        .firstWhere((calendar) => calendar.calendar.name == 'Work');
    await container
        .read(calendarTabProvider.notifier)
        .show(work.file, shown: false);

    expect(await tab(), [('Home', true), ('Work', false)]);
  });

  test('a calendar changed on disk is read anew', () async {
    write('home.ics', newCalendarText('Home'));
    await start();
    expect(await tab(), [('Home', true)]);

    write('home.ics', newCalendarText('Garden'));
    await container.read(folderContentsProvider.notifier).refresh();

    expect(await tab(), [('Garden', true)]);
  });
}
