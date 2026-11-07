import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/calendar_tab/calendar_tab_controller.dart';
import 'package:truce_editor/files/files_wiring.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  /// The files read whole, and by name only, in order.
  late List<String> wholeReads;
  late List<String> titleReads;

  void write(String name, String text) =>
      File('${dir.path}/$name').writeCreatingFolders(text);

  setUp(() async {
    dir = tempFolder();
    wholeReads = [];
    titleReads = [];
    container = ProviderContainer(
      overrides: [
        calendarReadsProvider.overrideWith(
          (ref) => FileReads(
            ref.watch(fileAccessProvider),
            readAs: (read) {
              wholeReads.add(read.path.name);
              return readCalendar(read);
            },
          ),
        ),
        calendarTitlesProvider.overrideWith(
          (ref) => FileReads(
            ref.watch(fileAccessProvider),
            readAs: (read) {
              titleReads.add(read.path.name);
              return readCalendarTitle(read);
            },
          ),
        ),
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

  /// The tab's calendars as their titles and places, by title.
  Future<List<(String, TabPlace)>> tab() async {
    final calendars = await container.read(calendarTabProvider.future);
    return [
      for (final calendar in calendars.offered)
        (
          calendar.title,
          switch (calendar) {
            ShownCalendar() => TabPlace.shown,
            OffCalendar() => TabPlace.off,
            UnreadableCalendar() => TabPlace.shown,
          },
        ),
      for (final calendar in calendars.hidden)
        (calendar.title, TabPlace.hidden),
    ].sortedBy((calendar) => calendar.$1.toLowerCase());
  }

  /// Puts the tab's calendar [title] in [place].
  Future<void> place(String title, TabPlace place) async {
    final calendars = await container.read(calendarTabProvider.future);
    final file = [
      for (final calendar in calendars.offered)
        if (calendar.title == title) calendar.file,
      for (final calendar in calendars.hidden)
        if (calendar.title == title) calendar.file,
    ].single;
    await container.read(calendarTabProvider.notifier).place(file, place);
  }

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
    expect(await tab(), [('Home', TabPlace.shown), ('Work', TabPlace.shown)]);

    await place('Work', TabPlace.off);
    expect(await tab(), [('Home', TabPlace.shown), ('Work', TabPlace.off)]);

    await place('Home', TabPlace.hidden);
    expect(await tab(), [('Home', TabPlace.hidden), ('Work', TabPlace.off)]);

    await place('Home', TabPlace.off);
    expect(await tab(), [('Home', TabPlace.off), ('Work', TabPlace.off)]);
  });

  test('only shown calendars are read whole, the others by name only; '
      'each once per version', () async {
    write('work.ics', newCalendarText('Work'));
    write('home.ics', newCalendarText('Home'));
    await start();
    await container.read(calendarTabProvider.future);
    expect(wholeReads, unorderedEquals(['home.ics', 'work.ics']));
    expect(titleReads, isEmpty);

    await place('Work', TabPlace.off);
    await place('Home', TabPlace.hidden);
    expect(await tab(), [('Home', TabPlace.hidden), ('Work', TabPlace.off)]);
    expect(wholeReads, hasLength(2), reason: 'none read whole again');
    expect(titleReads, unorderedEquals(['home.ics', 'work.ics']));

    await place('Work', TabPlace.shown);
    expect(await tab(), [('Home', TabPlace.hidden), ('Work', TabPlace.shown)]);
    expect(wholeReads.skip(2), ['work.ics']);
    expect(titleReads, hasLength(2), reason: 'Home kept as read');
  });

  test("a shown calendar whose events can't be read keeps its chip, "
      'greyed', () async {
    write('half.ics', 'BEGIN:VCALENDAR\nX-WR-CALNAME:Half\nBEGIN:VEVENT\n');
    await start();

    expect(
      (await container.read(calendarTabProvider.future)).offered.single,
      isA<UnreadableCalendar>(),
    );
    await place('Half', TabPlace.hidden);
    expect(await tab(), [('Half', TabPlace.hidden)]);
  });

  test('a calendar without a name is titled and sorted by its file, as '
      'its card', () async {
    write('home.ics', newCalendarText('Home'));
    write('apples.ics', newCalendarText(''));
    write('zoo.ics', newCalendarText('Zoo'));
    await start();

    // By title, not by the raw name (empty for apples.ics), in any case.
    expect(await tab(), [
      ('apples', TabPlace.shown),
      ('Home', TabPlace.shown),
      ('Zoo', TabPlace.shown),
    ]);
  });

  test('a calendar changed on disk is read anew', () async {
    write('home.ics', newCalendarText('Home'));
    await start();
    expect(await tab(), [('Home', TabPlace.shown)]);

    write('home.ics', newCalendarText('Garden'));
    await container.read(folderContentsProvider.notifier).refresh();

    expect(await tab(), [('Garden', TabPlace.shown)]);
  });
}
