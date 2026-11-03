import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../calendar_start.dart';
import '../views/calendar_views.dart';
import '../views/new_event_spot.dart';
import 'event_actions.dart';
import 'health_actions.dart';

/// A calendar's page: the calendar in the calendar views. Tap an event to
/// see it whole and to edit or delete it (a health entry in its own
/// form); tap a free time or day to add one (to a health calendar: an
/// entry of a kind picked first); drag an event or its edge to move that
/// one date. It takes what [starts] asks (the Add button, the Calendar
/// tab's Edit) once it can be edited. Only to read unless [edit] is
/// given.
class EventsPage extends StatefulWidget {
  const EventsPage(
    this.calendar, {
    this.edit,
    required this.now,
    required this.deviceZone,
    required this.viewChoice,
    required this.color,
    required this.starts,
    required this.hint,
    super.key,
  });

  final Calendar calendar;
  final MakeEdit? edit;
  final DateTime Function() now;
  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;
  final Color color;
  final PageStarts starts;
  final void Function(String message) hint;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  /// The day Add starts on, as the views tell it.
  late DateTime _addDay = DateUtils.dateOnly(widget.now());

  @override
  void initState() {
    super.initState();
    widget.starts.addListener(_takeSoon);
    _takeSoon();
  }

  @override
  void didUpdateWidget(EventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A start waits while the calendar can't be edited yet.
    if (oldWidget.edit == null && widget.edit != null) {
      _takeSoon();
    }
  }

  @override
  void dispose() {
    widget.starts.removeListener(_takeSoon);
    super.dispose();
  }

  /// Takes the start asked once the frame is drawn: a start can be asked
  /// while the page builds, and the views tell the day to add as they
  /// show.
  void _takeSoon() => WidgetsBinding.instance
    ..addPostFrameCallback((_) => _takeStart())
    ..ensureVisualUpdate();

  void _takeStart() {
    final edit = widget.edit;
    if (!mounted || edit == null) return;
    switch (widget.starts.take()) {
      case StartAdding():
        unawaited(_add(AtTimes.usualOn(_addDay), edit));
      case final EditOccurrence asked:
        unawaited(_editAsked(asked, edit));
      case null:
    }
  }

  Future<void> _editAsked(EditOccurrence asked, MakeEdit edit) async {
    final start = asked.start;
    final occurrence =
        occurrences(
          widget.calendar,
          start,
          start.add(const Duration(days: 1)),
        ).firstWhereOrNull(
          (each) =>
              each.event.uid == asked.uid &&
              each.recurrence == asked.recurrence &&
              each.start == start,
        );
    if (occurrence == null) {
      return widget.hint('This event is no longer in the calendar.');
    }
    await (occurrence.part.health == null
        ? editOccurrence(context, occurrence, edit, widget.deviceZone)
        : editHealthEntry(context, occurrence, edit));
  }

  /// Adds at [spot]: an event, or a health entry of a kind picked first.
  Future<void> _add(NewEventSpot spot, MakeEdit edit) =>
      widget.calendar.isHealth
      ? addHealthEntry(context, spot.firstDay, edit)
      : addEvent(context, spot, edit, widget.deviceZone);

  @override
  Widget build(BuildContext context) {
    final edit = widget.edit;
    final calendar = widget.calendar;
    final deviceZone = widget.deviceZone;
    return CalendarViews<()>(
      calendars: {(): calendar},
      colorOf: (_) => widget.color,
      kind: widget.viewChoice.last(),
      onKind: (kind) => unawaited(widget.viewChoice.keep(kind)),
      now: widget.now,
      onTap: (_, occurrence) => occurrence.part.health == null
          ? showOccurrence(context, occurrence, edit, deviceZone)
          : showHealthEntry(context, occurrence, edit),
      onAdd: edit == null ? null : (spot) => _add(spot, edit),
      onAddDay: (day) => _addDay = day,
      onMove: edit == null
          ? null
          : (_, occurrence, start, end) =>
                edit(occurrenceMovedTo(occurrence, start, end)),
    );
  }
}
