import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/empty_state.dart';
import '../../common/snack.dart';
import '../../files/file_colors.dart';
import '../../files/ui/open_file.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../settings/calendar_view_setting.dart';
import '../calendar_clock.dart';
import '../calendar_tab_controller.dart';
import 'calendar_dot.dart';
import 'open_calendar.dart';
import 'pick_calendar.dart';

/// The Calendar tab: the events of every calendar of the shown folders in
/// the calendar views, each in its calendar's color; chips turn a
/// calendar's events on and off. It only shows: tap an event to see it,
/// then open its calendar or edit it there; the floating button opens a
/// calendar; a tap or drag on a free time says to open one. Every edit
/// happens on the calendar's own page.
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
      appBar: AppBar(title: const Text('Calendars')),
      floatingActionButton: calendars.isEmpty
          ? null
          : FloatingActionButton(
              // The files' button is in the same page, beside it.
              heroTag: null,
              tooltip: 'Open calendar',
              onPressed: () => _openCalendar(context, ref, colorOf),
              child: const Icon(Icons.calendar_month_outlined),
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
                          avatar: CalendarDot(colorOf(calendar.file)),
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
                    // Adding happens on a calendar's page.
                    onAdd: (_) => showSnack(
                      context,
                      'Open one calendar to edit',
                      actionLabel: 'Open',
                      onAction: () => _openCalendar(context, ref, colorOf),
                    ),
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

  /// Opens one of the tab's calendars as they are now, the user's pick,
  /// on its own page.
  Future<void> _openCalendar(
    BuildContext context,
    WidgetRef ref,
    Color Function(ListedFile file) colorOf,
  ) async {
    // The hint's Open may come after the tab is gone.
    if (!context.mounted) return;
    final calendars = ref.read(calendarTabProvider).value ?? const [];
    final picked = await pickCalendar(context, calendars, colorOf);
    if (picked == null || !context.mounted) return;
    await openFile(context, ref, picked);
  }
}
