import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

import '../files/file_settings_controller.dart';
import '../files/files_wiring.dart';
import '../folder_state/folder_state_controller.dart';

/// One calendar the Calendar tab knows, by its place there ([TabPlace]):
/// its listed [file] and its [title] as its card shows it.
sealed class TabCalendar {
  const TabCalendar(this.file, this.title);

  final ListedFile file;
  final String title;
}

/// A calendar whose events the tab shows: its [calendar] as read.
final class ShownCalendar extends TabCalendar {
  const ShownCalendar(super.file, super.title, this.calendar);

  final Calendar calendar;
}

/// A calendar the tab offers but doesn't show; only its name is read.
final class OffCalendar extends TabCalendar {
  const OffCalendar(super.file, super.title);
}

/// A calendar left out of the tab, only listed to bring it back; only
/// its name is read.
final class HiddenCalendar extends TabCalendar {
  const HiddenCalendar(super.file, super.title);
}

/// A calendar as the tab keeps it read: the [calendar] and its [title].
typedef ReadCalendar = ({Calendar calendar, String title});

/// The calendars of the tab as read, kept while the app runs; a file
/// that is no calendar is left out.
final calendarReadsProvider = Provider<FileReads<ReadCalendar>>(
  (ref) => FileReads(ref.watch(fileAccessProvider), readAs: readCalendar),
);

/// [read] as the tab keeps a calendar it shows; `null` if it is none.
ReadCalendar? readCalendar(FileText read) => switch (read.summary) {
  CalendarSummary(:final calendar?) => (
    calendar: calendar,
    title: titleOf(read.summary, read.path),
  ),
  _ => null,
};

/// The titles of the tab's calendars it doesn't show, read from their
/// names alone (no events), kept while the app runs; a file that is no
/// calendar is left out.
final calendarTitlesProvider = Provider<FileReads<String>>(
  (ref) => FileReads(ref.watch(fileAccessProvider), readAs: readCalendarTitle),
);

/// The title of the calendar [read], from its head alone; `null` if it is
/// none.
String? readCalendarTitle(FileText read) =>
    switch (CalendarHead.read(read.text)) {
      final head? => calendarTitle(head) ?? nameTitle(read.path),
      null => null,
    };

/// Whether the shown folders hold a calendar: the tab shows only then.
final hasCalendarsProvider = Provider<bool>(
  (ref) => ref.watch(
    folderFilesProvider.select(
      (shown) => shown?.files.any(isCalendarFile) ?? false,
    ),
  ),
);

/// Whether [file] is a calendar.
bool isCalendarFile(ListedFile file) => file.type.type == calendarType;

final calendarTabProvider =
    AsyncNotifierProvider<CalendarTabController, List<TabCalendar>>(
      CalendarTabController.new,
    );

/// The Calendar tab's calendars: every calendar the shown folders hold,
/// by title, each in the place the user gave it on this device; only the
/// shown ones are read whole, as they are now.
class CalendarTabController extends AsyncNotifier<List<TabCalendar>> {
  @override
  Future<List<TabCalendar>> build() async {
    final listed = await ref.watch(loadedFolderFiles);
    await ref.watch(fileSettingsProvider.future);
    final settings = ref.read(fileSettingsProvider.notifier);
    TabPlace placeOf(ListedFile file) =>
        CalendarView.of(settings.settingsOf(file.key).view).tab;
    final calendars = listed.files.where(isCalendarFile).toList();
    final (read, titled) = await (
      ref.read(calendarReadsProvider).readAll([
        for (final file in calendars)
          if (placeOf(file) == TabPlace.shown) file,
      ]),
      ref.read(calendarTitlesProvider).readAll([
        for (final file in calendars)
          if (placeOf(file) != TabPlace.shown) file,
      ]),
    ).wait;
    return <TabCalendar>[
      for (final MapEntry(key: file, value: (:calendar, :title))
          in read.entries)
        ShownCalendar(file, title, calendar),
      for (final MapEntry(key: file, value: title) in titled.entries)
        switch (placeOf(file)) {
          TabPlace.hidden => HiddenCalendar(file, title),
          // Shown ones are read whole, above.
          TabPlace.off || TabPlace.shown => OffCalendar(file, title),
        },
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Puts [file] in [place] in the tab.
  Future<void> place(ListedFile file, TabPlace place) => ref
      .read(fileSettingsProvider.notifier)
      .edit(
        file.key,
        (settings) => settings.withView(CalendarView(tab: place).settings),
      );
}
