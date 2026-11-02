import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../device_zone.dart';
import '../views/calendar_view_choice.dart';
import '../views/calendar_views.dart';
import '../views/occurrence_event.dart';
import 'event_actions.dart';

/// A calendar in the calendar views: tap an event to edit or delete it;
/// tap a free time or day, or Add event, to add one; drag an event or its
/// edge to move that one date. Only to read unless [edit] is given.
class EventsPage extends StatelessWidget {
  const EventsPage(
    this.calendar, {
    this.edit,
    required this.now,
    required this.deviceZone,
    required this.viewChoice,
    super.key,
  });

  final Calendar calendar;
  final MakeEdit? edit;
  final DateTime Function() now;
  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;

  @override
  Widget build(BuildContext context) {
    final edit = this.edit;
    return CalendarViews<()>(
      calendars: {(): calendar},
      colorOf: (_) => Theme.of(context).colorScheme.primary,
      kind: viewChoice.last(),
      onKind: (kind) => unawaited(viewChoice.keep(kind)),
      now: now,
      onTap: edit == null
          ? null
          : (_, occurrence) =>
                showOccurrenceActions(context, occurrence, edit, deviceZone),
      onAdd: edit == null
          ? null
          : (spot) => addEvent(context, spot, edit, deviceZone),
      onMove: edit == null
          ? null
          : (_, occurrence, start, end) =>
                edit(movedTo(occurrence, start, end)),
    );
  }
}
