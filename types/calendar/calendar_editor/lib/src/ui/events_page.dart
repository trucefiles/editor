import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../calendar_start.dart';
import '../views/calendar_views.dart';
import 'event_actions.dart';
import 'health_actions.dart';

/// A calendar's page: the calendar in the calendar views. Tap an event to
/// see it whole and to edit or delete it (a health entry in its own
/// form); tap a free time or day, or Add ([addAsked]), to add one (to a
/// health calendar: an entry of a kind picked first); drag an event or
/// its edge to move that one date. Once it shows, it does what [start]
/// gives when [starts] fires (e.g. the Calendar tab's Edit). Only to read
/// unless [edit] is given.
class EventsPage extends StatefulWidget {
  const EventsPage(
    this.calendar, {
    this.edit,
    required this.now,
    required this.deviceZone,
    required this.viewChoice,
    required this.color,
    required this.addAsked,
    required this.starts,
    required this.start,
    required this.hint,
    super.key,
  });

  final Calendar calendar;
  final MakeEdit? edit;
  final DateTime Function() now;
  final DeviceZone deviceZone;
  final CalendarViewChoice viewChoice;
  final Color color;
  final Listenable addAsked;
  final Listenable starts;

  /// The start asked of this page, taken; `null` if none.
  final CalendarStart? Function() start;
  final void Function(String message) hint;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _startAdding = AddAsks();
  late final _adding = Listenable.merge([widget.addAsked, _startAdding]);

  @override
  void initState() {
    super.initState();
    widget.starts.addListener(_takeStart);
    // Once the views show.
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeStart());
  }

  @override
  void didUpdateWidget(EventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A start waits while the calendar can't be edited yet.
    if (oldWidget.edit == null && widget.edit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _takeStart());
    }
  }

  @override
  void dispose() {
    widget.starts.removeListener(_takeStart);
    _startAdding.dispose();
    super.dispose();
  }

  void _takeStart() {
    final edit = widget.edit;
    if (!mounted || edit == null) return;
    switch (widget.start()) {
      case StartAdding():
        _startAdding.ask();
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
      onAdd: edit == null
          ? null
          : (spot) => calendar.isHealth
                ? addHealthEntry(context, spot.firstDay, edit)
                : addEvent(context, spot, edit, deviceZone),
      addAsked: _adding,
      onMove: edit == null
          ? null
          : (_, occurrence, start, end) =>
                edit(occurrenceMovedTo(occurrence, start, end)),
    );
  }
}
