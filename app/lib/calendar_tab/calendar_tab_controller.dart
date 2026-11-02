import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

import '../files/file_settings_controller.dart';
import '../files/files_wiring.dart';
import '../folder_state/folder_state_controller.dart';

/// One calendar the Calendar tab knows: its listed [file], its
/// [calendar] as read, its [title] as its card shows it, and whether the
/// tab shows its events ([shown]).
typedef TabCalendar = ({
  ListedFile file,
  Calendar calendar,
  String title,
  bool shown,
});

/// A calendar as the tab keeps it read: the [calendar] and its [title].
typedef ReadCalendar = ({Calendar calendar, String title});

/// The calendars of the tab as read, kept while the app runs; a file
/// that is no calendar is left out.
final calendarReadsProvider = Provider<FileReads<ReadCalendar>>(
  (ref) => FileReads(
    ref.watch(fileAccessProvider),
    readAs: (read) => switch (read.summary) {
      CalendarSummary(:final calendar?) => (
        calendar: calendar,
        title: titleOf(read.summary, read.path),
      ),
      _ => null,
    },
  ),
);

/// Whether the shown folders hold a calendar: the tab shows only then.
final hasCalendarsProvider = Provider<bool>(
  (ref) => ref.watch(
    folderContentsProvider.select(
      (contents) => contents.value?.files.any(isCalendarFile) ?? false,
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
/// read as it is now, by title; each shown in the tab or not, as the user
/// set it on this device.
class CalendarTabController extends AsyncNotifier<List<TabCalendar>> {
  @override
  Future<List<TabCalendar>> build() async {
    final contents = await ref.watch(folderContentsProvider.future);
    await ref.watch(fileSettingsProvider.future);
    final settings = ref.read(fileSettingsProvider.notifier);
    final read = await ref
        .read(calendarReadsProvider)
        .readAll(contents.files.where(isCalendarFile).toList());
    return [
      for (final MapEntry(key: file, value: (:calendar, :title))
          in read.entries)
        (
          file: file,
          calendar: calendar,
          title: title,
          shown: CalendarView.of(settings.settingsOf(file.key).view).inTab,
        ),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// The tab shows [file]'s events if [shown].
  Future<void> show(ListedFile file, {required bool shown}) => ref
      .read(fileSettingsProvider.notifier)
      .edit(
        file.key,
        (settings) => settings.withView(CalendarView(inTab: shown).settings),
      );
}
