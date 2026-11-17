import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import 'alert_field.dart';
import 'color_choice.dart';
import 'leave_check.dart';
import 'repeat_field.dart';
import 'time_row.dart';

/// Opens the task form on [draft] (a new task's, or what a task says
/// now), titled [title]; the draft as the user saved it, or `null` if
/// they backed out. Offers a repeat, and to drop the due date, unless
/// the task is one date of a series ([repeats] false). [deviceZone] is
/// this device's time zone, if known; a due date turned on starts on
/// [today].
Future<TaskDraft?> showTaskForm(
  BuildContext context,
  TaskDraft draft, {
  required String title,
  required String? deviceZone,
  required DateTime today,
  bool repeats = true,
}) => Navigator.push(
  context,
  MaterialPageRoute<TaskDraft>(
    fullscreenDialog: true,
    builder: (_) => TaskForm(
      draft,
      title: title,
      deviceZone: deviceZone,
      today: today,
      repeats: repeats,
    ),
  ),
);

/// The task form: title, a due day (or none) and maybe a time of day,
/// and with a due day its repeat and alert; color and notes. What it
/// doesn't show of the task (its start, place, other alarms) stays as it
/// was; a new due time keeps the start where it fits, or moves it along
/// ([TaskDraft.withDue]). A
/// time keeps the zone it was written in; a new one is in the device's.
class TaskForm extends StatefulWidget {
  const TaskForm(
    this.draft, {
    required this.title,
    required this.deviceZone,
    required this.today,
    this.repeats = true,
    super.key,
  });

  final TaskDraft draft;
  final String title;

  /// This device's time zone; `null` if unknown.
  final String? deviceZone;

  /// Today, at midnight: where a due date turned on starts.
  final DateTime today;

  /// Whether the form offers a repeat: not for one date of a series.
  final bool repeats;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  late final _summary = TextEditingController(text: widget.draft.summary);
  late final _notes = TextEditingController(text: widget.draft.description);
  late final _openedDue = _FormDue.of(widget.draft.due);
  late var _due = _openedDue;
  late var _repeat = widget.draft.repeat;
  late var _alerts = widget.draft.alerts;
  late var _color = widget.draft.color;

  /// The draft as the form opened, as it reads it back.
  late final TaskDraft _opened;

  @override
  void initState() {
    super.initState();
    _opened = _drafted;
  }

  @override
  void dispose() {
    _summary.dispose();
    _notes.dispose();
    super.dispose();
  }

  TaskDraft get _drafted {
    final was = widget.draft.due;
    // A due time the user left as it was keeps its own bytes.
    final timed = _due == _openedDue
        ? widget.draft
        : widget.draft.withDue(_due?.asTime(was, widget.deviceZone));
    // Only a due date turned off here drops what goes with it; a task
    // that has none (one that only starts) keeps them.
    final dropped = _due == null && _openedDue != null;
    return TaskDraft(
      summary: _summary.text.trim(),
      due: timed.due,
      start: timed.start,
      description: _notes.text,
      location: widget.draft.location,
      repeat: dropped ? null : _repeat,
      alerts: dropped ? const [] : _alerts,
      color: _color,
    );
  }

  @override
  Widget build(BuildContext context) => LeaveCheck(
    changed: () => _drafted != _opened,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _drafted),
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
            // One date of a series can be moved, but not made undated.
            if (widget.repeats || _openedDue == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date'),
                value: _due != null,
                onChanged: (due) => setState(
                  () => _due = due ? _FormDue.on(widget.today) : null,
                ),
              ),
            if (_due case final due?) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('At a time'),
                value: due.time != null,
                onChanged: (timed) => setState(
                  () => _due = due.withTime(
                    timed ? const TimeOfDay(hour: 9, minute: 0) : null,
                  ),
                ),
              ),
              TimeRow(
                label: 'Due',
                day: due.day,
                time: due.time,
                onDay: (day) => setState(() => _due = due.withDay(day)),
                onTime: (time) => setState(() => _due = due.withTime(time)),
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
                at: 'When due',
                onAlerts: (alerts) => setState(() => _alerts = alerts),
              ),
            ],
            const SizedBox(height: 16),
            ColorChoice(
              color: _color,
              onColor: (color) => setState(() => _color = color),
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
    ),
  );
}

/// When a task is due, as the form shows it: a [day], and a [time] of day
/// unless it is due all day; on its own zone's clock.
final class _FormDue {
  const _FormDue(this.day, this.time);

  /// Due all day on [day].
  const _FormDue.on(DateTime day) : this(day, null);

  /// [due] as the form shows it; `null` for never.
  static _FormDue? of(CalendarTime? due) {
    if (due == null) return null;
    final wall = due.editWall;
    return _FormDue(
      DateTime(wall.year, wall.month, wall.day),
      due is AllDay ? null : TimeOfDay(hour: wall.hour, minute: wall.minute),
    );
  }

  final DateTime day;
  final TimeOfDay? time;

  _FormDue withDay(DateTime day) => _FormDue(day, time);

  _FormDue withTime(TimeOfDay? time) => _FormDue(day, time);

  /// The due time, of [was]'s kind if that is a time of day (so a task
  /// keeps its zone), else in [deviceZone] (see [timeAt]).
  CalendarTime asTime(CalendarTime? was, String? deviceZone) => timeAt(
    DateTime.utc(
      day.year,
      day.month,
      day.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    ),
    allDay: time == null,
    was: was,
    deviceZone: deviceZone,
  );

  @override
  bool operator ==(Object other) =>
      other is _FormDue && other.day == day && other.time == time;

  @override
  int get hashCode => Object.hash(day, time);
}
