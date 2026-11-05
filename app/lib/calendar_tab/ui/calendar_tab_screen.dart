import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/empty_state.dart';
import '../../files/file_colors.dart';
import '../../files/ui/open_file.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../settings/calendar_view_setting.dart';
import '../calendar_tab_controller.dart';
import '../calendar_tab_picks.dart';
import 'open_calendar.dart';

/// The Calendar tab: the events of every calendar of the shown folders in
/// the calendar views, each in its calendar's color; chips turn a
/// calendar's events on and off. It only shows: tap an event to see it,
/// then open its calendar or edit it there; + picks a calendar and starts
/// adding on its page. Every edit happens on the calendar's own page.
class CalendarTabScreen extends ConsumerWidget {
  const CalendarTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(calendarTabProvider).value ?? const [];
    final viewChoice = ref.watch(calendarViewChoiceProvider);
    final shown = ref.watch(folderFilesProvider);
    Color colorOf(ListedFile file) =>
        fileColor(shown?.markOf(file.key).color, folder: file.folder.color);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: calendars.isEmpty
          ? null
          : FloatingActionButton(
              // The files' button is in the same page, beside it.
              heroTag: null,
              tooltip: 'Add event',
              onPressed: () => _openForAdding(
                context,
                ref,
                forAdding(calendars, ref.read(lastUsedCalendarProvider)),
              ),
              child: const Icon(Icons.add),
            ),
      body: calendars.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_month_outlined,
              text: 'No calendars yet.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final calendar in calendars)
                        FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: colorOf(calendar.file),
                          ),
                          label: Text(calendar.title),
                          selected: calendar.shown,
                          onSelected: (on) => ref
                              .read(calendarTabProvider.notifier)
                              .show(calendar.file, shown: on),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: CalendarViews<ListedFile>(
                    calendars: <ListedFile, Calendar>{
                      for (final calendar in calendars)
                        if (calendar.shown) calendar.file: calendar.calendar,
                    },
                    colorOf: colorOf,
                    kind: viewChoice.last(),
                    onKind: (kind) => unawaited(viewChoice.keep(kind)),
                    now: ref.watch(calendarClockProvider),
                    titleOf: (file) => calendars
                        .firstWhere((calendar) => calendar.file == file)
                        .title,
                    onTap: (file, occurrence) =>
                        _showEvent(context, ref, file, occurrence),
                  ),
                ),
              ],
            ),
    );
  }

  /// Shows [occurrence] of the calendar [file] whole, with what can be
  /// done with it: open its calendar, or edit it there.
  Future<void> _showEvent(
    BuildContext context,
    WidgetRef ref,
    ListedFile file,
    Occurrence occurrence,
  ) async {
    final edit = await showOccurrenceSheet(context, occurrence, [
      (
        icon: Icons.calendar_month_outlined,
        label: 'Open calendar',
        value: false,
      ),
      (icon: Icons.edit_outlined, label: 'Edit', value: true),
    ]);
    if (edit == null || !context.mounted) return;
    await (edit
        ? openCalendar(context, ref, file, EditOccurrence.of(occurrence))
        : openFile(context, ref, file));
  }

  /// Asks which of [calendars] to add to, and starts adding on its page.
  Future<void> _openForAdding(
    BuildContext context,
    WidgetRef ref,
    List<TabCalendar> calendars,
  ) async {
    final picked = calendars.length == 1
        ? calendars.single.file
        : await showDialog<ListedFile>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Add to which calendar?'),
              children: [
                for (final calendar in calendars)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, calendar.file),
                    child: Text(calendar.title),
                  ),
              ],
            ),
          );
    if (picked == null || !context.mounted) return;
    ref.read(lastUsedCalendarProvider.notifier).addTo(picked);
    await openCalendar(context, ref, picked, const StartAdding());
  }
}
