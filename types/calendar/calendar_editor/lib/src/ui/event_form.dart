import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import '../views/new_event_spot.dart';
import 'color_choice.dart';
import 'leave_check.dart';

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

/// The alerts the form offers, before the start.
const alertChoices = [
  Duration.zero,
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(days: 1),
];

/// How a form's repeat choice reads.
const _frequencyWords = {
  Frequency.daily: 'Every day',
  Frequency.weekly: 'Every week',
  Frequency.monthly: 'Every month',
  Frequency.yearly: 'Every year',
};

/// The event form: title, all day, start and end, repeat, alert, color,
/// place and notes. What it doesn't show of the event (e.g. a health
/// entry, a time zone) stays as it was; an event in another zone than
/// the device's shows its own clock, its zone named below the times; an
/// event in UTC shows on the device's clock and stays in UTC.
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
        : _times.end(widget.draft.start, widget.deviceZone),
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
            _TimeRow(
              label: 'Starts',
              day: _times.startDay,
              time: _times.allDay ? null : _times.startTime,
              onDay: (day) => setState(() => _times = _times.withStartDay(day)),
              onTime: (time) =>
                  setState(() => _times = _times.withStartTime(time)),
            ),
            _TimeRow(
              label: 'Ends',
              day: _times.endDay,
              time: _times.allDay ? null : _times.endTime,
              onDay: (day) => setState(() => _times = _times.copy(endDay: day)),
              onTime: (time) =>
                  setState(() => _times = _times.copy(endTime: time)),
            ),
            if (_otherZone case final zone?)
              Text(
                'Times are in $zone.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!ok)
              Text(
                'It ends before it starts.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            if (widget.repeats)
              switch (_repeat) {
                OtherRepeat(:final rule) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeats'),
                  subtitle: Text("$rule (can't be changed here)"),
                ),
                final SimpleRepeat? repeat =>
                  DropdownButtonFormField<Frequency?>(
                    initialValue: repeat?.frequency,
                    decoration: const InputDecoration(labelText: 'Repeats'),
                    items: [
                      const DropdownMenuItem(child: Text('Never')),
                      for (final MapEntry(key: frequency, value: text)
                          in _frequencyWords.entries)
                        DropdownMenuItem(value: frequency, child: Text(text)),
                    ],
                    onChanged: (frequency) => setState(
                      () => _repeat = switch (frequency) {
                        null => null,
                        // The rest of a repeat the form shows stays.
                        _ when repeat?.frequency == frequency => repeat,
                        final frequency => SimpleRepeat(frequency),
                      },
                    ),
                  ),
              },
            const SizedBox(height: 8),
            DropdownButtonFormField<_Alerts>(
              initialValue: _Alerts(_alerts),
              decoration: const InputDecoration(labelText: 'Alert'),
              items: [
                const DropdownMenuItem(value: _Alerts([]), child: Text('None')),
                if (_alerts.isNotEmpty && !_offered(_alerts))
                  DropdownMenuItem(
                    value: _Alerts(_alerts),
                    child: Text(_alerts.map(alertText).join(', ')),
                  ),
                for (final before in alertChoices)
                  DropdownMenuItem(
                    value: _Alerts([before]),
                    child: Text(alertText(before)),
                  ),
              ],
              onChanged: (alerts) =>
                  setState(() => _alerts = alerts?.before ?? const []),
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
            const SizedBox(height: 16),
            Text(
              "Alerts are saved, but the app doesn't remind you yet.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// The event's zone if its times are of another zone than the device's.
  String? get _otherZone => switch (widget.draft.start) {
    _ when _times.allDay => null,
    Zoned(:final zone) when zone != widget.deviceZone => zone,
    _ => null,
  };

  /// Whether [alerts] is one the list offers.
  bool _offered(List<Duration> alerts) =>
      alerts.length == 1 && alertChoices.contains(alerts.single);
}

/// The alerts a choice of the form's list stands for, equal by their
/// times (a list alone is equal only to itself).
final class _Alerts {
  const _Alerts(this.before);

  final List<Duration> before;

  static const _equality = ListEquality<Duration>();

  @override
  bool operator ==(Object other) =>
      other is _Alerts && _equality.equals(other.before, before);

  @override
  int get hashCode => _equality.hash(before);
}

/// How an alert [before] the start reads.
String alertText(Duration before) => switch (before) {
  Duration.zero => 'At the start',
  _ when before.inDays > 0 && before.inHours % 24 == 0 =>
    before.inDays == 1 ? '1 day before' : '${before.inDays} days before',
  _ when before.inMinutes % 60 == 0 =>
    before.inHours == 1 ? '1 hour before' : '${before.inHours} hours before',
  _ => '${before.inMinutes} minutes before',
};

/// One row of a day and, unless all day, a time of day, each a button that
/// asks for a new one.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.day,
    required this.time,
    required this.onDay,
    required this.onTime,
  });

  final String label;
  final DateTime day;
  final TimeOfDay? time;
  final void Function(DateTime day) onDay;
  final void Function(TimeOfDay time) onTime;

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final time = this.time;
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (picked != null) onDay(picked);
            },
            child: Text(words.formatMediumDate(day)),
          ),
        ),
        if (time != null)
          TextButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked != null) onTime(picked);
            },
            child: Text(
              words.formatTimeOfDay(
                time,
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The start and end as the form shows them: days and times of day on the
/// event's own clock (its wall clock), the last day of an all-day event
/// itself (not the day after).
final class _FormTimes {
  const _FormTimes({
    required this.allDay,
    required this.startDay,
    required this.startTime,
    required this.endDay,
    required this.endTime,
  });

  factory _FormTimes.of(EventDraft draft) {
    final (start, end) = (draft.start.editWall, draft.end.editWall);
    final allDay = draft.start is AllDay;
    final lastDay = allDay ? end.subtract(const Duration(days: 1)) : end;
    return _FormTimes(
      allDay: allDay,
      startDay: DateTime(start.year, start.month, start.day),
      startTime: TimeOfDay(hour: start.hour, minute: start.minute),
      endDay: DateTime(lastDay.year, lastDay.month, lastDay.day),
      endTime: TimeOfDay(hour: end.hour, minute: end.minute),
    );
  }

  final bool allDay;
  final DateTime startDay;
  final TimeOfDay startTime;
  final DateTime endDay;
  final TimeOfDay endTime;

  DateTime get _startWall => _wall(startDay, allDay ? null : startTime);
  DateTime get _endWall => allDay
      ? DateTime.utc(endDay.year, endDay.month, endDay.day + 1)
      : _wall(endDay, endTime);

  bool get endsAfterStart => !_endWall.isBefore(_startWall);

  /// The start, of [was]'s kind unless the form changed all day (see
  /// [timeAt]).
  CalendarTime start(CalendarTime was, String? deviceZone) =>
      timeAt(_startWall, allDay: allDay, was: was, deviceZone: deviceZone);

  /// The end, of [was]'s kind unless the form changed all day.
  CalendarTime end(CalendarTime was, String? deviceZone) =>
      timeAt(_endWall, allDay: allDay, was: was, deviceZone: deviceZone);

  _FormTimes copy({
    bool? allDay,
    DateTime? startDay,
    TimeOfDay? startTime,
    DateTime? endDay,
    TimeOfDay? endTime,
  }) => _FormTimes(
    allDay: allDay ?? this.allDay,
    startDay: startDay ?? this.startDay,
    startTime: startTime ?? this.startTime,
    endDay: endDay ?? this.endDay,
    endTime: endTime ?? this.endTime,
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

  /// A new start time moves the end along, so the event keeps its length.
  _FormTimes withStartTime(TimeOfDay time) {
    final length = _endWall.difference(_startWall);
    final end = _wall(startDay, time).add(length);
    return copy(
      startTime: time,
      endDay: DateTime(end.year, end.month, end.day),
      endTime: TimeOfDay(hour: end.hour, minute: end.minute),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _FormTimes &&
      other.allDay == allDay &&
      other.startDay == startDay &&
      other.startTime == startTime &&
      other.endDay == endDay &&
      other.endTime == endTime;

  @override
  int get hashCode => Object.hash(allDay, startDay, startTime, endDay, endTime);

  static DateTime _wall(DateTime day, TimeOfDay? time) => DateTime.utc(
    day.year,
    day.month,
    day.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );
}
