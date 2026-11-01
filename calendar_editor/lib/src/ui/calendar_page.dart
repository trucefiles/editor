import 'package:flutter/material.dart';

import '../calendar_editor_part.dart';
import 'events_page.dart';
import 'health_page.dart';

/// The calendar [part]'s editor shows, as it changes: a health calendar
/// as its health view, any other as its events; a text that is no
/// calendar as it is, to read. Edits only while the part is editing.
class CalendarPage extends StatelessWidget {
  const CalendarPage(this.part, {required this.today, super.key});

  final CalendarEditorPart part;
  final DateTime today;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: part.owner.changes,
    builder: (context, _) {
      final state = part.owner.state;
      final edit = part.isEditing ? part.edit : null;
      return switch (state.calendar) {
        null => _NoCalendar(state.text),
        final calendar when calendar.isHealth => HealthPage(
          calendar,
          edit: edit,
          today: today,
        ),
        final calendar => EventsPage(calendar, edit: edit, today: today),
      };
    },
  );
}

/// A text that can't be read as a calendar: shown as it is.
class _NoCalendar extends StatelessWidget {
  const _NoCalendar(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'This file can\'t be read as a calendar. It shows as it is, and '
        'nothing here changes it.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
    ],
  );
}
