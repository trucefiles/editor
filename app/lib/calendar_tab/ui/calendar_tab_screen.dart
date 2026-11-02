import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/empty_state.dart';
import '../../documents/ui/document_grid.dart';
import '../../folders/folder_colors.dart';
import '../../settings/calendar_view_setting.dart';
import '../calendar_tab_controller.dart';
import '../calendar_tab_picks.dart';

/// The Calendar tab: the events of every calendar of the shown folders in
/// the calendar views, each in its folder's color; chips turn a
/// calendar's events on and off. Tap an event to open its calendar; +
/// opens a calendar to add one there. Nothing is dragged here: each
/// calendar is edited on its own page.
class CalendarTabScreen extends ConsumerWidget {
  const CalendarTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(calendarTabProvider).value ?? const [];
    final viewChoice = ref.watch(calendarViewChoiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: calendars.isEmpty
          ? null
          : FloatingActionButton(
              // The documents' button is in the same page, beside it.
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
                ),
                Expanded(
                  child: CalendarViews<Document>(
                    calendars: <Document, Calendar>{
                      for (final calendar in calendars)
                        if (calendar.shown)
                          calendar.document: calendar.calendar,
                    },
                    colorOf: (document) => folderColor(document.folder.color),
                    kind: viewChoice.last(),
                    onKind: (kind) => unawaited(viewChoice.keep(kind)),
                    now: ref.watch(calendarClockProvider),
                    onTap: (document, _) =>
                        openDocument(context, ref, document),
                  ),
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
    ref.read(lastUsedCalendarProvider.notifier).addTo(picked);
    await openDocument(context, ref, picked);
  }
}
