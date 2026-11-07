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
import '../calendar_clock.dart';
import '../calendar_tab_controller.dart';
import '../tab_view_setting.dart';
import 'calendar_chip.dart';
import 'hidden_calendars.dart';
import 'open_calendar.dart';
import 'pick_calendar.dart';

/// The Calendar tab: the events of every calendar of the shown folders in
/// the calendar views, each in its calendar's color; chips turn a
/// calendar's events on and off, or hide it from the tab, and the last
/// chip brings hidden ones back. It only shows: tap an event to see it,
/// then open its calendar or edit it there; the floating button opens a
/// calendar; a tap or drag on a free time says to open one. Every edit
/// happens on the calendar's own page.
class CalendarTabScreen extends ConsumerWidget {
  const CalendarTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(calendarTabProvider).value ?? TabCalendars.none;
    final controller = ref.read(calendarTabProvider.notifier);
    final viewChoice = ref.watch(tabViewChoiceProvider);
    final listed = ref.watch(folderFilesProvider);
    Color colorOf(ListedFile file) =>
        fileColor(listed?.markOf(file.key).color, folder: file.folder.color);
    final TabCalendars(:offered, :hidden, :shown) = calendars;
    return Scaffold(
      appBar: AppBar(title: const Text('Calendars')),
      floatingActionButton: offered.isEmpty
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
                      for (final calendar in offered)
                        CalendarChip(
                          calendar,
                          color: colorOf(calendar.file),
                          onShown: (on) => controller.place(
                            calendar.file,
                            on ? TabPlace.shown : TabPlace.off,
                          ),
                          onHide: () =>
                              controller.place(calendar.file, TabPlace.hidden),
                        ),
                      if (hidden.isNotEmpty)
                        HiddenCalendarsChip(
                          hidden,
                          colorOf: colorOf,
                          onShowAgain: (file) =>
                              controller.place(file, TabPlace.off),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: CalendarViews<ListedFile>(
                    calendars: {
                      for (final MapEntry(key: file, value: calendar)
                          in shown.entries)
                        file: calendar.calendar,
                    },
                    colorOf: colorOf,
                    kind: viewChoice.last(),
                    onKind: (kind) => unawaited(viewChoice.keep(kind)),
                    now: ref.watch(calendarClockProvider),
                    titleOf: (file) => shown[file]!.title,
                    onTap: (file, occurrence) => _showEvent(
                      context,
                      ref,
                      shown[file]!,
                      occurrence,
                      colorOf(file),
                    ),
                    // Adding happens on a calendar's page, if one can open.
                    onAdd: offered.isEmpty
                        ? null
                        : (_) => showSnack(
                            context,
                            'Open one calendar to edit',
                            actionLabel: 'Open',
                            onAction: () =>
                                _openCalendar(context, ref, colorOf),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Shows [occurrence] of [calendar] whole, named with its [color] and
  /// title, with what can be done with it: open its calendar, or edit it
  /// there.
  Future<void> _showEvent(
    BuildContext context,
    WidgetRef ref,
    ShownCalendar calendar,
    Occurrence occurrence,
    Color color,
  ) async {
    final file = calendar.file;
    final edit = await showOccurrenceSheet(
      context,
      occurrence,
      [
        (
          icon: Icons.calendar_month_outlined,
          label: 'Open calendar',
          value: false,
        ),
        (icon: Icons.edit_outlined, label: 'Edit', value: true),
      ],
      calendar: (color: color, title: calendar.title),
    );
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
    final offered = ref.read(calendarTabProvider).value?.offered ?? const [];
    final picked = await pickCalendar(context, offered, colorOf);
    if (picked == null || !context.mounted) return;
    await openFile(context, ref, picked);
  }
}
