import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/empty_state.dart';
import '../../documents/ui/document_grid.dart';
import '../../folders/folder_colors.dart';
import '../calendar_month_controller.dart';
import '../calendar_tab_controller.dart';

/// The Calendar tab: the events of every calendar of the shown folders in
/// one month grid and the picked day's list, each in its folder's color;
/// chips turn a calendar's events on and off. Tap an event to open its
/// calendar; + opens a calendar to add one there.
class CalendarTabScreen extends ConsumerWidget {
  const CalendarTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = MaterialLocalizations.of(context);
    final month = ref.watch(
      calendarTabMonthProvider(words.firstDayOfWeekIndex),
    );
    final picks = ref.read(calendarTabPicksProvider.notifier);
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: month.calendars.isEmpty
          ? null
          : FloatingActionButton(
              // The documents' button is in the same page, beside it.
              heroTag: null,
              tooltip: 'Add event',
              onPressed: () => _openForAdding(context, ref, month.forAdding),
              child: const Icon(Icons.add),
            ),
      body: month.calendars.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_month_outlined,
              text: 'No calendars yet.',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final calendar in month.calendars)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: folderColor(
                            calendar.document.folder.color,
                          ),
                        ),
                        label: Text(tabCalendarName(calendar)),
                        selected: calendar.shown,
                        onSelected: (on) => ref
                            .read(calendarTabProvider.notifier)
                            .show(calendar.document, shown: on),
                      ),
                  ],
                ),
                MonthHeader(month: month.picks.month, onMonth: picks.showMonth),
                MonthGrid(
                  month: month.picks.month,
                  selected: month.picks.day,
                  today: month.picks.today,
                  lookOf: (day) => (
                    marked: month.counts[day] ?? 0,
                    filled: false,
                    hatched: false,
                    tinted: false,
                  ),
                  onPick: picks.pickDay,
                ),
                const Divider(),
                ListTile(
                  title: Text(
                    words.formatFullDate(month.picks.day),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (month.ofDay.isEmpty)
                  const ListTile(title: Text('Nothing on this day.'))
                else
                  for (final (:calendar, :occurrence) in month.ofDay)
                    ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 14,
                        color: folderColor(calendar.document.folder.color),
                      ),
                      title: Text(occurrenceTitle(occurrence)),
                      subtitle: Text(
                        [
                          timesOf(words, occurrence, use24Hour: use24Hour),
                          tabCalendarName(calendar),
                        ].join(' · '),
                      ),
                      onTap: () =>
                          openDocument(context, ref, calendar.document),
                    ),
              ],
            ),
    );
  }

  /// Asks which of [calendars] to add an event to, and opens it.
  Future<void> _openForAdding(
    BuildContext context,
    WidgetRef ref,
    List<TabCalendar> calendars,
  ) async {
    final picked = calendars.length == 1
        ? calendars.single.document
        : await showDialog<Document>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Add to which calendar?'),
              children: [
                for (final calendar in calendars)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, calendar.document),
                    child: Text(tabCalendarName(calendar)),
                  ),
              ],
            ),
          );
    if (picked == null || !context.mounted) return;
    ref.read(calendarTabPicksProvider.notifier).addTo(picked);
    await openDocument(context, ref, picked);
  }
}
