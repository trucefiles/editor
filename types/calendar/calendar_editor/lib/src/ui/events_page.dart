import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../calendar_clock.dart';
import '../calendar_start.dart';
import '../views/calendar_views.dart';
import '../views/new_event_spot.dart';
import 'health_actions.dart';
import 'item_actions.dart';
import 'new_kind.dart';

/// A calendar's page: the calendar in the calendar views. Tap an event or
/// a task to see it whole and to edit or delete it (a health entry in its
/// own form); tap a task's box to check it off; tap a free time or day to
/// add an event or a task there, the user's pick (to a health calendar:
/// an entry of a kind picked first; in the tasks view: a task); drag an
/// event or a task, or an event's edge, to move that one date. It takes
/// what [starts] asks (the Add button, the Calendar tab's Edit) once it
/// can be edited, and shows first where they ask, else in its own view
/// on today. Only to read unless [edit] is given.
class EventsPage extends StatefulWidget {
  const EventsPage(
    this.calendar, {
    this.edit,
    required this.clock,
    required this.deviceZone,
    required this.viewChoice,
    required this.color,
    required this.starts,
    required this.hint,
    super.key,
  });

  final Calendar calendar;
  final MakeEdit? edit;
  final CalendarClock clock;
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
  late DateTime _addDay = DateUtils.dateOnly(widget.clock.now());

  /// Where the views show first.
  late final ShowAt? _showAt;

  /// The view shown.
  late CalendarViewKind _kind;

  @override
  void initState() {
    super.initState();
    _showAt = widget.starts.takeShowAt();
    _kind = _showAt?.kind ?? widget.viewChoice.last();
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
        unawaited(
          _addsTasks
              ? _addTask(null, edit)
              : _add(AtTimes.usualOn(_addDay), edit),
        );
      case final EditOccurrence asked:
        unawaited(_editAsked(asked, edit));
      case final EditTask asked:
        unawaited(_editTaskAsked(asked, edit));
      case null:
    }
  }

  Future<void> _editAsked(EditOccurrence asked, MakeEdit edit) async {
    final start = asked.start;
    final occurrence = _occurrencesAround(start)
        .whereType<EventOccurrence>()
        .firstWhereOrNull(
          (each) =>
              each.item.uid == asked.uid &&
              each.recurrence?.local == asked.recurrence &&
              each.start == start,
        );
    if (occurrence == null) {
      return widget.hint('This event is no longer in the calendar.');
    }
    await (occurrence.part.health == null
        ? editOccurrence(
            context,
            occurrence,
            edit,
            widget.deviceZone,
            today: _today,
          )
        : editHealthEntry(context, occurrence, edit));
  }

  Future<void> _editTaskAsked(EditTask asked, MakeEdit edit) async {
    final task = widget.calendar.taskOf(asked.uid);
    final entry = switch ((task, asked.due)) {
      (final task?, null)
          when task.series.from == null && !task.series.deleted =>
        TaskEntry.undated(task),
      (_?, final due?) =>
        _occurrencesAround(due)
            .whereType<TaskOccurrence>()
            .where(
              (each) =>
                  each.item.uid == asked.uid &&
                  each.recurrence?.local == asked.date &&
                  each.due == due,
            )
            .map(TaskEntry.of)
            .firstOrNull,
      _ => null,
    };
    if (entry == null) {
      return widget.hint('This task is no longer in the calendar.');
    }
    await editTask(context, entry, edit, widget.deviceZone, today: _today);
  }

  /// The occurrences of the calendar from a day before [at] to a day
  /// after.
  List<Occurrence> _occurrencesAround(DateTime at) => occurrences(
    widget.calendar,
    at.subtract(const Duration(days: 1)),
    at.add(const Duration(days: 1)),
  );

  DateTime get _today => DateUtils.dateOnly(widget.clock.now());

  /// Adds at [spot]: a health entry of a kind picked first; in the tasks
  /// view a task; else an event or a task, the user's pick.
  Future<void> _add(NewEventSpot spot, MakeEdit edit) async {
    if (widget.calendar.isHealth) {
      return addHealthEntry(context, spot.firstDay, edit);
    }
    if (_addsTasks) {
      return _addTask(spot, edit);
    }
    final kind = await pickNewKind(context);
    if (!mounted) return;
    switch (kind) {
      case NewKind.event:
        await addEvent(context, spot, edit, widget.deviceZone);
      case NewKind.task:
        await _addTask(spot, edit);
      case null:
    }
  }

  /// Whether adding adds a task, without asking: in the tasks view of a
  /// calendar that is no health calendar.
  bool get _addsTasks =>
      !widget.calendar.isHealth && _kind == CalendarViewKind.tasks;

  Future<void> _addTask(NewEventSpot? spot, MakeEdit edit) =>
      addTask(context, spot, edit, widget.deviceZone, today: _today);

  @override
  Widget build(BuildContext context) {
    final edit = widget.edit;
    final calendar = widget.calendar;
    final deviceZone = widget.deviceZone;
    return CalendarViews<()>(
      calendars: {(): calendar},
      colorOf: (_) => widget.color,
      kind: _kind,
      day: _showAt?.day,
      time: _showAt?.time,
      onKind: (kind) {
        _kind = kind;
        unawaited(widget.viewChoice.keep(kind));
      },
      clock: widget.clock,
      onTap: (_, occurrence) => occurrence.part.health == null
          ? showOccurrence(context, occurrence, edit, deviceZone, today: _today)
          : showHealthEntry(context, occurrence, edit),
      onTask: (_, entry) =>
          showTask(context, entry, edit, deviceZone, today: _today),
      onCheck: edit == null
          ? null
          : (_, entry, done) => edit(
              (at) => CheckTask(entry.task.uid, entry.date, done: done, at: at),
            ),
      onAdd: edit == null ? null : (spot) => _add(spot, edit),
      onAddDay: (day) => _addDay = day,
      onMove: edit == null
          ? null
          : (_, occurrence, start, end) =>
                edit(occurrenceMovedTo(occurrence, start, end)),
    );
  }
}
