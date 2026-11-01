import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_documents/truce_documents.dart';

import '../documents/document_settings_controller.dart';
import '../documents/documents_wiring.dart';
import '../folder_state/folder_state_controller.dart';
import 'calendar_reads.dart';

/// One calendar the Calendar tab knows: its listed [document], its
/// [calendar] as read, and whether the tab shows its events ([shown]).
typedef TabCalendar = ({Document document, Calendar calendar, bool shown});

/// The calendar reads of the tab, kept while the app runs.
final calendarReadsProvider = Provider<CalendarReads>(
  (ref) => CalendarReads(ref.watch(folderFilesProvider)),
);

/// Whether the shown folders hold a calendar: the tab shows only then.
final hasCalendarsProvider = Provider<bool>(
  (ref) => ref.watch(
    folderContentsProvider.select(
      (contents) => contents.value?.documents.any(isCalendarDocument) ?? false,
    ),
  ),
);

/// Whether [document] is a calendar.
bool isCalendarDocument(Document document) =>
    document.type.type == calendarType;

final calendarTabProvider =
    AsyncNotifierProvider<CalendarTabController, List<TabCalendar>>(
      CalendarTabController.new,
    );

/// The Calendar tab's calendars: every calendar the shown folders hold,
/// read as it is now, by name; each shown in the tab or not, as the user
/// set it on this device.
class CalendarTabController extends AsyncNotifier<List<TabCalendar>> {
  @override
  Future<List<TabCalendar>> build() async {
    final contents = await ref.watch(folderContentsProvider.future);
    await ref.watch(documentSettingsProvider.future);
    final settings = ref.read(documentSettingsProvider.notifier);
    final read = await ref.read(calendarReadsProvider).readAll([
      for (final document in contents.documents)
        if (isCalendarDocument(document))
          (document: document, version: contents.versionOf(document)),
    ]);
    return [
      for (final MapEntry(key: document, value: calendar) in read.entries)
        (
          document: document,
          calendar: calendar,
          shown: CalendarView.of(settings.settingsOf(document.key).view).inTab,
        ),
    ]..sort((a, b) => a.calendar.name.compareTo(b.calendar.name));
  }

  /// The tab shows [document]'s events if [shown].
  Future<void> show(Document document, {required bool shown}) => ref
      .read(documentSettingsProvider.notifier)
      .edit(
        document.key,
        (settings) => settings.withView(CalendarView(inTab: shown).settings),
      );
}
