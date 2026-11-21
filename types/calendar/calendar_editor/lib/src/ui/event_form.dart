import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import '../views/new_event_spot.dart';
import 'alert_field.dart';
import 'color_choice.dart';
import 'leave_check.dart';
import 'repeat_field.dart';
import 'time_row.dart';

/// Opens the event form on [draft] (a new event's, or what an event says
/// now), titled [title]; the draft as the user saved it, or `null` if
/// they backed out. Offers a repeat unless the event is one of a series
/// ([repeats] false). [deviceZone] is this device's time zone, if known.
Future<EventDraft?> showEventForm(
  BuildContext context,
  EventDraft draft, {
  required String title,
  required String? deviceZone,
  bool repeats = true,
}) => Navigator.push(
  context,
  MaterialPageRoute<EventDraft>(
    fullscreenDialog: true,
    builder: (_) => EventForm(
      draft,
      title: title,
      deviceZone: deviceZone,
      repeats: repeats,
    ),
  ),
);

/// The event form: title, all day, start and end each with its time
/// zone, repeat, alert, color, place and notes. What it doesn't show of
/// the event (e.g. a health entry) stays as it was. Each time shows on
/// its own zone's clock, the zone named where it isn't the device's (a
/// flight may start and end in two); picking a zone keeps the clock time
/// as typed. An event in UTC shows on the device's clock and stays in
/// UTC unless a zone is picked; there is no way back to no zone.
class EventForm extends StatefulWidget {
  const EventForm(
    this.draft, {
    required this.title,
    required this.deviceZone,
    this.repeats = true,
    super.key,
  });

  final EventDraft draft;
  final String title;

  /// This device's time zone; `null` if unknown.
  final String? deviceZone;

  /// Whether the form offers a repeat: not for one of a series.
  final bool repeats;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  late final _summary = TextEditingController(text: widget.draft.summary);
  late final _location = TextEditingController(text: widget.draft.location);
  late final _notes = TextEditingController(text: widget.draft.description);
  late final _openedTimes = _FormTimes.of(widget.draft);
  late var _times = _openedTimes;
  late var _repeat = widget.draft.repeat;
  late var _alerts = widget.draft.alerts;
  late var _color = widget.draft.color;

  /// The draft as the form opened, as it reads it back.
  late final EventDraft _opened;

  @override
  void initState() {
    super.initState();
    _opened = _drafted;
  }

  @override
  void dispose() {
    _summary.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  EventDraft get _drafted => EventDraft(
    summary: _summary.text.trim(),
    // Times the user left as they were keep their own bytes (e.g. seconds,
    // which the form doesn't show), so they don't count as changed.
    start: _times == _openedTimes
        ? widget.draft.start
        : _times.start(widget.draft.start, widget.deviceZone),
    end: _times == _openedTimes
        ? widget.draft.end
        : _times.end(widget.draft.end, widget.deviceZone),
    description: _notes.text,
    location: _location.text.trim(),
    repeat: _repeat,
    alerts: _alerts,
    health: widget.draft.health,
    color: _color,
  );

  @override
  Widget build(BuildContext context) {
    final ok = _times.endsAfterStart;
    return LeaveCheck(
      changed: () => _drafted != _opened,
      child: _scaffold(context, ok: ok),
    );
  }

  Widget _scaffold(BuildContext context, {required bool ok}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: ok ? () => Navigator.pop(context, _drafted) : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: PageWidth(
        builder: (_, padding) => ListView(
          padding: padding + const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _summary,
              autofocus: widget.draft.summary.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _times.allDay,
              onChanged: (allDay) =>
                  setState(() => _times = _times.withAllDay(allDay)),
            ),
            TimeRow(
              label: 'Starts',
              day: _times.startDay,
              time: _times.allDay ? null : _times.startTime,
              zone: _zoneShown(_times.startZone, _openedTimes.startZone),
              onDay: (day) => setState(() => _times = _times.withStartDay(day)),
              onTime: (time) =>
                  setState(() => _times = _times.withStartTime(time)),
              onZone: (zone) =>
                  setState(() => _times = _times.withStartZone(zone)),
            ),
            TimeRow(
              label: 'Ends',
              day: _times.endDay,
              time: _times.allDay ? null : _times.endTime,
              zone: _zoneShown(_times.endZone, _openedTimes.endZone),
              onDay: (day) => setState(() => _times = _times.copy(endDay: day)),
              onTime: (time) =>
                  setState(() => _times = _times.copy(endTime: time)),
              onZone: (zone) =>
                  setState(() => _times = _times.copy(endZone: zone)),
            ),
            if (!ok)
              Text(
                'It ends before it starts.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            if (widget.repeats)
              RepeatField(
                repeat: _repeat,
                onRepeat: (repeat) => setState(() => _repeat = repeat),
              ),
            const SizedBox(height: 8),
            AlertField(
              alerts: _alerts,
              onAlerts: (alerts) => setState(() => _alerts = alerts),
            ),
            const SizedBox(height: 16),
            ColorChoice(
              color: _color,
              onColor: (color) => setState(() => _color = color),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
    );
  }

  /// [zone] as its time's row names it, [opened] the zone it had as the
  /// form opened: `null` (no name) where it is none, or the device's as
  /// before, as the device's clock needs no name; a zone just picked is
  /// always named, so the change shows.
  String? _zoneShown(String? zone, String? opened) =>
      zone == widget.deviceZone && zone == opened ? null : zone;
}

/// The start and end as the form shows them: days and times of day each
/// on its own zone's clock (its wall clock; a zone of `null` is the
/// device's), the last day of an all-day event itself (not the day
/// after).
final class _FormTimes {
  const _FormTimes({
    required this.allDay,
    required this.startDay,
    required this.startTime,
    required this.startZone,
    required this.endDay,
    required this.endTime,
    required this.endZone,
  });

  factory _FormTimes.of(EventDraft draft) {
    final (start, end) = (draft.start.editWall, draft.end.editWall);
    final allDay = draft.start is AllDay;
    final lastDay = allDay ? end.subtract(const Duration(days: 1)) : end;
    return _FormTimes(
      allDay: allDay,
      startDay: DateTime(start.year, start.month, start.day),
      startTime: TimeOfDay(hour: start.hour, minute: start.minute),
      startZone: draft.start.zone,
      endDay: DateTime(lastDay.year, lastDay.month, lastDay.day),
      endTime: TimeOfDay(hour: end.hour, minute: end.minute),
      endZone: draft.end.zone,
    );
  }

  final bool allDay;
  final DateTime startDay;
  final TimeOfDay startTime;
  final String? startZone;
  final DateTime endDay;
  final TimeOfDay endTime;
  final String? endZone;

  DateTime get _startWall => _wall(startDay, allDay ? null : startTime);
  DateTime get _endWall => allDay
      ? DateTime.utc(endDay.year, endDay.month, endDay.day + 1)
      : _wall(endDay, endTime);

  /// The start and end as moments, each read on its own clock.
  CalendarTime get _startClock => _clock(_startWall, startZone);
  CalendarTime get _endClock => _clock(_endWall, endZone);

  bool get endsAfterStart => allDay
      ? !_endWall.isBefore(_startWall)
      : !_endClock.local.isBefore(_startClock.local);

  /// The start, of [was]'s kind unless the form changed all day or
  /// picked a zone (see [_timeAt]).
  CalendarTime start(CalendarTime was, String? deviceZone) =>
      _timeAt(_startWall, startZone, was: was, deviceZone: deviceZone);

  /// The end, likewise.
  CalendarTime end(CalendarTime was, String? deviceZone) =>
      _timeAt(_endWall, endZone, was: was, deviceZone: deviceZone);

  /// The time at [wall]: in [zone] if it has one and is no day; else as
  /// [timeAt] makes it.
  CalendarTime _timeAt(
    DateTime wall,
    String? zone, {
    required CalendarTime was,
    required String? deviceZone,
  }) => switch (zone) {
    final zone? when !allDay => Zoned(zone, wall),
    _ => timeAt(wall, allDay: allDay, was: was, deviceZone: deviceZone),
  };

  _FormTimes copy({
    bool? allDay,
    DateTime? startDay,
    TimeOfDay? startTime,
    String? startZone,
    DateTime? endDay,
    TimeOfDay? endTime,
    String? endZone,
  }) => _FormTimes(
    allDay: allDay ?? this.allDay,
    startDay: startDay ?? this.startDay,
    startTime: startTime ?? this.startTime,
    startZone: startZone ?? this.startZone,
    endDay: endDay ?? this.endDay,
    endTime: endTime ?? this.endTime,
    endZone: endZone ?? this.endZone,
  );

  /// All day on keeps the days; off gives the start day the usual hour
  /// of a new event, as the days' own times (midnight) mean nothing.
  _FormTimes withAllDay(bool allDay) => allDay
      ? copy(allDay: true)
      : switch (AtTimes.usualOn(startDay)) {
          AtTimes(:final start, :final end) => copy(
            allDay: false,
            startTime: TimeOfDay.fromDateTime(start),
            endDay: startDay,
            endTime: TimeOfDay.fromDateTime(end),
          ),
        };

  /// A new start day moves the end along, so the event keeps its length.
  _FormTimes withStartDay(DateTime day) {
    final moved = _wall(day, null).difference(_wall(startDay, null)).inDays;
    return copy(
      startDay: day,
      endDay: DateTime(endDay.year, endDay.month, endDay.day + moved),
    );
  }

  /// A new start time moves the end along, so the event keeps its real
  /// length, also when it ends in another zone.
  _FormTimes withStartTime(TimeOfDay time) {
    final length = _endClock.local.difference(_startClock.local);
    final start = _clock(_wall(startDay, time), startZone).local;
    final end = _endClock.sameKindAt(start.add(length)).wall;
    return copy(
      startTime: time,
      endDay: DateTime(end.year, end.month, end.day),
      endTime: TimeOfDay(hour: end.hour, minute: end.minute),
    );
  }

  /// A new start zone, the clock times kept; the end takes it too while
  /// it was in the start's.
  _FormTimes withStartZone(String zone) =>
      copy(startZone: zone, endZone: endZone == startZone ? zone : endZone);

  @override
  bool operator ==(Object other) =>
      other is _FormTimes &&
      other.allDay == allDay &&
      other.startDay == startDay &&
      other.startTime == startTime &&
      other.startZone == startZone &&
      other.endDay == endDay &&
      other.endTime == endTime &&
      other.endZone == endZone;

  @override
  int get hashCode => Object.hash(
    allDay,
    startDay,
    startTime,
    startZone,
    endDay,
    endTime,
    endZone,
  );

  static DateTime _wall(DateTime day, TimeOfDay? time) => DateTime.utc(
    day.year,
    day.month,
    day.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );

  /// [wall] on the clock of [zone]; `null` is the device's.
  static CalendarTime _clock(DateTime wall, String? zone) =>
      zone == null ? Floating(wall) : Zoned(zone, wall);
}
