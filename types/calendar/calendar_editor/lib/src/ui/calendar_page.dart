import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../calendar_editor_part.dart';
import '../calendar_start.dart';
import 'event_actions.dart';
import 'events_page.dart';

/// The calendar [part]'s editor shows, as it changes: the calendar's
/// page; a text that is no calendar as it is, to read. Edits only while
/// the part is editing. An edit saved as a new event says why.
class CalendarPage extends StatefulWidget {
  const CalendarPage(
    this.part, {
    required this.now,
    required this.hint,
    required this.deviceZone,
    required this.viewChoice,
    required this.color,
    required this.starts,
    super.key,
  });

  final CalendarEditorPart part;

  /// The time now; today shows from it.
  final DateTime Function() now;

  /// The view event calendars open in, and where a new pick is kept.
  final CalendarViewChoice viewChoice;

  /// Tells this device's time zone, for new events.
  final DeviceZone deviceZone;

  /// The calendar's color: its events show in it unless they have
  /// their own.
  final Color color;

  /// What the page is asked to start with: adding, or editing an event.
  final PageStarts starts;

  /// Shows a short hint, e.g. that an edit was not made.
  final void Function(String message) hint;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final StreamSubscription<GoneMeanwhile> _savedAsNew;

  @override
  void initState() {
    super.initState();
    _savedAsNew = widget.part.savedAsNew.listen(
      (gone) => widget.hint(_savedAsNewHint(gone)),
    );
  }

  @override
  void dispose() {
    unawaited(_savedAsNew.cancel());
    super.dispose();
  }

  /// Makes [edit], or says why it can't be made.
  void _edit(CalendarEdit Function(DateTime at) edit) {
    if (!widget.part.edit(edit)) {
      widget.hint("The calendar can't be edited right now.");
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: widget.part.owner.changes,
    builder: (context, _) {
      final part = widget.part;
      final state = part.owner.state;
      final MakeEdit? edit = part.isEditing ? _edit : null;
      return switch (state.calendar) {
        null => _NoCalendar(state.text),
        final calendar => EventsPage(
          calendar,
          edit: edit,
          now: widget.now,
          deviceZone: widget.deviceZone,
          viewChoice: widget.viewChoice,
          color: widget.color,
          starts: widget.starts,
          hint: widget.hint,
        ),
      };
    },
  );
}

/// Why an edit was saved as a new event, for the user.
String _savedAsNewHint(GoneMeanwhile gone) => switch (gone) {
  GoneMeanwhile.event =>
    "This event was deleted on another device, so it's saved as a new one.",
  GoneMeanwhile.date =>
    "This date of the event changed on another device, so it's saved as "
        'a new event.',
};

/// A text that can't be read as a calendar: shown as it is.
class _NoCalendar extends StatelessWidget {
  const _NoCalendar(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        "This file can't be read as a calendar, so it's shown as "
        "plain text and can't be changed here.",
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
    ],
  );
}
