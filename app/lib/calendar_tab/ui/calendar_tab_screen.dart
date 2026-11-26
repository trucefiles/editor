import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/empty_state.dart';
import '../../common/snack.dart';
import '../../file_types/calendar_wiring.dart';
import '../../files/file_colors.dart';
import '../../files/ui/open_file.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../text_zoom/ui/file_text_zoom.dart';
import '../calendar_clock.dart';
import '../calendar_tab_controller.dart';
import '../tab_view_setting.dart';
import 'calendar_chip.dart';
import 'hidden_calendars.dart';
import 'open_calendar.dart';
import 'pick_calendar.dart';

/// The Calendar tab: the events and tasks of every calendar of the shown
/// folders in the calendar views, each in its calendar's color; chips
/// turn a calendar's items on and off, or hide it from the tab, and the
/// last chip brings hidden ones back. It only shows: tap an event or a
/// task to see it, then open its calendar on its day in the tab's view,
/// or edit it there; a task is checked off on its calendar's page, not
/// here; the floating button opens a calendar; a tap or drag on a free
/// time says to open one. Every edit happens on the calendar's own page.
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChipRow(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  chips: [
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
                Expanded(
                  // Event text, zoomed like a calendar's own page.
                  child: FileTextZoom(
                    child: EventLinks(
                      openers: ref.watch(eventOpenersProvider),
                      hint: (message) => showSnack(context, message),
                      // Its own context, so an event's sheet opens with the
                      // zoom and the links above.
                      child: Builder(
                        builder: (zoomed) => CalendarViews<ListedFile>(
                          calendars: {
                            for (final MapEntry(key: file, value: calendar)
                                in shown.entries)
                              file: calendar.calendar,
                          },
                          colorOf: colorOf,
                          kind: viewChoice.last(),
                          onKind: (kind) => unawaited(viewChoice.keep(kind)),
                          clock: ref.watch(calendarClockProvider),
                          titleOf: (file) => shown[file]!.title,
                          onTap: (file, occurrence) => _showItem(
                            zoomed,
                            ref,
                            shown[file]!,
                            colorOf(file),
                            edit: EditOccurrence.of(occurrence),
                            showAt: ShowAt.occurrence(
                              viewChoice.last(),
                              occurrence,
                            ),
                            sheet: (actions, calendar) => showOccurrenceSheet(
                              zoomed,
                              occurrence,
                              actions,
                              calendar: calendar,
                            ),
                          ),
                          onTask: (file, entry) => _showItem(
                            zoomed,
                            ref,
                            shown[file]!,
                            colorOf(file),
                            edit: EditTask.of(entry),
                            showAt: ShowAt.task(viewChoice.last(), entry),
                            sheet: (actions, calendar) => showTaskSheet(
                              zoomed,
                              entry,
                              actions,
                              calendar: calendar,
                            ),
                          ),
                          // Adding happens on a calendar's page, if one can
                          // open.
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
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Shows an event or a task of [calendar] whole in its [sheet], named
  /// with its [color] and title, with what can be done with it: open its
  /// calendar, or [edit] it there; either way the calendar shows
  /// [showAt] first.
  Future<void> _showItem(
    BuildContext context,
    WidgetRef ref,
    ShownCalendar calendar,
    Color color, {
    required CalendarStart edit,
    required ShowAt showAt,
    required Future<bool?> Function(
      List<OccurrenceAction<bool>> actions,
      SheetCalendar calendar,
    )
    sheet,
  }) async {
    final file = calendar.file;
    final editing = await sheet(
      [
        (
          icon: Icons.calendar_month_outlined,
          label: 'Show in calendar',
          value: false,
        ),
        (icon: Icons.edit_outlined, label: 'Edit', value: true),
      ],
      (color: color, title: calendar.title),
    );
    if (editing == null || !context.mounted) return;
    await openCalendar(
      context,
      ref,
      file,
      editing ? edit : null,
      showAt: showAt,
    );
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
