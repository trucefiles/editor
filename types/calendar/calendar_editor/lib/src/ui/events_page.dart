import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../views/calendar_views.dart';
import 'event_actions.dart';
import 'health_actions.dart';

/// A calendar's page: the calendar in the calendar views. Tap an event to
/// see it whole and to edit or delete it (a health entry in its own
/// form); tap a free time or day, or Add, to add one (to a health
/// calendar: an entry of a kind picked first); drag an event or its edge
/// to move that one date. Only to read unless [edit] is given.
class EventsPage extends StatelessWidget {
  const EventsPage(
    this.calendar, {
    this.edit,
    required this.now,
    required this.deviceZone,
    required this.viewChoice,
    required this.color,
    super.key,
  });

  final Calendar calendar;
  final MakeEdit? edit;
  final DateTime Function() now;
  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final edit = this.edit;
    return CalendarViews<()>(
      calendars: {(): calendar},
      colorOf: (_) => color,
      kind: viewChoice.last(),
      onKind: (kind) => unawaited(viewChoice.keep(kind)),
      now: now,
      onTap: (_, occurrence) => occurrence.part.health == null
          ? showOccurrence(context, occurrence, edit, deviceZone)
          : showHealthEntry(context, occurrence, edit),
      onAdd: edit == null
          ? null
          : (spot) => calendar.isHealth
                ? addHealthEntry(context, spot.firstDay, edit)
                : addEvent(context, spot, edit, deviceZone),
      onMove: edit == null
          ? null
          : (_, occurrence, start, end) =>
                edit(occurrenceMovedTo(occurrence, start, end)),
    );
  }
}
