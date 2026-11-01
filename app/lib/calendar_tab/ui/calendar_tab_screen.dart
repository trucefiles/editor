import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/empty_state.dart';
import '../../documents/ui/document_grid.dart';
import '../../folders/folder_colors.dart';
import '../calendar_tab_controller.dart';

/// The Calendar tab: the events of every calendar of the shown folders in
/// one month grid and the picked day's list, each in its folder's color;
/// chips turn a calendar's events on and off. Tap an event to open its
/// calendar; + opens a calendar to add one there.
class CalendarTabScreen extends ConsumerStatefulWidget {
  const CalendarTabScreen({super.key});

  @override
  ConsumerState<CalendarTabScreen> createState() => _CalendarTabScreenState();
}

class _CalendarTabScreenState extends ConsumerState<CalendarTabScreen> {
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late var _month = DateTime(_today.year, _today.month);
  late var _day = _today;

  /// The calendar + opened last, offered first next time.
  Document? _lastUsed;

  @override
  Widget build(BuildContext context) {
    final calendars = ref.watch(calendarTabProvider).value ?? const [];
    final shown = {
      for (final calendar in calendars)
        if (calendar.shown) calendar: calendar.calendar,
    };
    final words = MaterialLocalizations.of(context);
    final (:first, :end) = gridDays(_month, words.firstDayOfWeekIndex);
    final counts = countsByDay(
      occurrencesOf(shown, first, end).map((each) => each.occurrence),
    );
    final ofDay = occurrencesOf(
      shown,
      _day,
      DateTime(_day.year, _day.month, _day.day + 1),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: calendars.isEmpty
          ? null
          : FloatingActionButton(
              // The documents' button is in the same page, beside it.
              heroTag: null,
              tooltip: 'Add event',
              onPressed: () => _openForAdding(calendars),
              child: const Icon(Icons.add),
            ),
      body: calendars.isEmpty
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
                    for (final calendar in calendars)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: folderColor(
                            calendar.document.folder.color,
                          ),
                        ),
                        label: Text(_nameOf(calendar)),
                        selected: calendar.shown,
                        onSelected: (on) => ref
                            .read(calendarTabProvider.notifier)
                            .show(calendar.document, shown: on),
                      ),
                  ],
                ),
                MonthHeader(
                  month: _month,
                  onMonth: (month) => setState(() => _month = month),
                ),
                MonthGrid(
                  month: _month,
                  selected: _day,
                  today: _today,
                  lookOf: (day) => (
                    marked: counts[day] ?? 0,
                    filled: false,
                    hatched: false,
                    tinted: false,
                  ),
                  onPick: (day) => setState(() {
                    _day = day;
                    _month = DateTime(day.year, day.month);
                  }),
                ),
                const Divider(),
                ListTile(
                  title: Text(
                    words.formatFullDate(_day),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (ofDay.isEmpty)
                  const ListTile(title: Text('Nothing on this day.'))
                else
                  for (final (:calendar, :occurrence) in ofDay)
                    ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 14,
                        color: folderColor(calendar.document.folder.color),
                      ),
                      title: Text(occurrenceTitle(occurrence)),
                      subtitle: Text(
                        '${timesOf(words, occurrence)} · ${_nameOf(calendar)}',
                      ),
                      onTap: () =>
                          openDocument(context, ref, calendar.document),
                    ),
              ],
            ),
    );
  }

  /// Asks which calendar to add an event to, the one used last first, and
  /// opens it.
  Future<void> _openForAdding(List<TabCalendar> calendars) async {
    final last = _lastUsed;
    final ordered = [
      ...calendars.where((each) => each.document == last),
      ...calendars.where((each) => each.document != last),
    ];
    final picked = ordered.length == 1
        ? ordered.single.document
        : await showDialog<Document>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Add to which calendar?'),
              children: [
                for (final calendar in ordered)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, calendar.document),
                    child: Text(_nameOf(calendar)),
                  ),
              ],
            ),
          );
    if (picked == null || !mounted) return;
    _lastUsed = picked;
    await openDocument(context, ref, picked);
  }

  /// What [calendar] is called: its own name, else its file's.
  static String _nameOf(TabCalendar calendar) =>
      switch (calendar.calendar.name.trim()) {
        '' => nameTitle(calendar.document.path),
        final name => name,
      };
}
