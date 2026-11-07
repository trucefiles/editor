import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

import '../files/file_settings_controller.dart';
import '../files/files_wiring.dart';
import '../folder_state/folder_state_controller.dart';

/// The Calendar tab's calendars, by title, each in its place there
/// ([TabPlace]) on this device.
final class TabCalendars {
  TabCalendars({required this.offered, required this.hidden});

  /// No calendars.
  static final none = TabCalendars(offered: const [], hidden: const []);

  /// The calendars with a chip, shown or off; also those to open.
  final List<OfferedCalendar> offered;

  /// The calendars left out, only listed to bring them back.
  final List<HiddenCalendar> hidden;

  /// The shown calendars, by file.
  late final Map<ListedFile, ShownCalendar> shown = {
    for (final calendar in offered.whereType<ShownCalendar>())
      calendar.file: calendar,
  };

  bool get isEmpty => offered.isEmpty && hidden.isEmpty;
}

/// A calendar with a chip in the tab: its listed [file] and its [title]
/// as its card shows it.
sealed class OfferedCalendar {
  const OfferedCalendar(this.file, this.title);

  final ListedFile file;
  final String title;
}

/// A calendar whose events the tab shows: its [calendar] as read.
final class ShownCalendar extends OfferedCalendar {
  const ShownCalendar(super.file, super.title, this.calendar);

  final Calendar calendar;
}

/// A calendar whose events the tab doesn't show, as the user turned it
/// off; only its name is read.
final class OffCalendar extends OfferedCalendar {
  const OffCalendar(super.file, super.title);
}

/// A calendar turned on whose events can't be read (e.g. a broken file);
/// only its name could be.
final class UnreadableCalendar extends OfferedCalendar {
  const UnreadableCalendar(super.file, super.title);
}

/// A calendar left out of the tab; only its name is read.
final class HiddenCalendar {
  const HiddenCalendar(this.file, this.title);

  final ListedFile file;
  final String title;
}

/// A calendar as the tab reads one it shows: its [calendar], `null` if
/// only its name could be read, and its [title].
typedef ReadCalendar = ({Calendar? calendar, String title});

/// The calendars of the tab as read, kept while the app runs; a file
/// that is no calendar is left out.
final calendarReadsProvider = Provider<FileReads<ReadCalendar>>(
  (ref) => FileReads(ref.watch(fileAccessProvider), readAs: readCalendar),
);

/// [read] as the tab keeps a calendar it shows: whole, else by its name
/// alone; `null` if it is no calendar.
ReadCalendar? readCalendar(FileText read) => switch (read.summary) {
  CalendarSummary(:final calendar?) => (
    calendar: calendar,
    title: titleOf(read.summary, read.path),
  ),
  _ => switch (readCalendarTitle(read)) {
    final title? => (calendar: null, title: title),
    null => null,
  },
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
      final head? => ownTitleOr(calendarTitle(head), read.path),
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
    AsyncNotifierProvider<CalendarTabController, TabCalendars>(
      CalendarTabController.new,
    );

/// The Calendar tab's calendars: every calendar the shown folders hold,
/// each in the place the user gave it on this device; only the shown
/// ones are read whole, as they are now.
class CalendarTabController extends AsyncNotifier<TabCalendars> {
  @override
  Future<TabCalendars> build() async {
    final listed = await ref.watch(loadedFolderFiles);
    await ref.watch(fileSettingsProvider.future);
    final settings = ref.read(fileSettingsProvider.notifier);
    final byPlace = listed.files
        .where(isCalendarFile)
        .groupListsBy(
          (file) => CalendarView.of(settings.settingsOf(file.key).view).tab,
        );
    List<ListedFile> filesIn(TabPlace place) => byPlace[place] ?? const [];
    final (shown, off, hidden) = (
      filesIn(TabPlace.shown),
      filesIn(TabPlace.off),
      filesIn(TabPlace.hidden),
    );
    final (read, titled) = await (
      ref.read(calendarReadsProvider).readAll(shown),
      ref.read(calendarTitlesProvider).readAll([...off, ...hidden]),
    ).wait;
    return TabCalendars(
      offered: [
        for (final MapEntry(key: file, value: (:calendar, :title))
            in read.entries)
          switch (calendar) {
            final calendar? => ShownCalendar(file, title, calendar),
            null => UnreadableCalendar(file, title),
          },
        for (final file in off)
          if (titled[file] case final title?) OffCalendar(file, title),
      ].sortedBy((calendar) => calendar.title.toLowerCase()),
      hidden: [
        for (final file in hidden)
          if (titled[file] case final title?) HiddenCalendar(file, title),
      ].sortedBy((calendar) => calendar.title.toLowerCase()),
    );
  }

  /// Puts [file] in [place] in the tab.
  Future<void> place(ListedFile file, TabPlace place) => ref
      .read(fileSettingsProvider.notifier)
      .edit(
        file.key,
        (settings) => settings.withView(
          CalendarView.of(settings.view).withTab(place).settings,
        ),
      );
}
