import 'package:collection/collection.dart';

import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_time.dart';
import '../model/item_part.dart';
import '../recurrence/occurrences.dart';

/// One task as the tasks list shows it: one date of it, or the task
/// itself where it has no due time.
final class TaskEntry {
  const TaskEntry._(
    this.task,
    this.part, {
    this.date,
    this.due,
    this.allDay = false,
  });

  /// The date [occurrence] of its task.
  TaskEntry.of(TaskOccurrence occurrence)
    : this._(
        occurrence.item,
        occurrence.part,
        date: occurrence.recurrence,
        due: occurrence.due,
        allDay: occurrence.allDay,
      );

  /// [task], which has no due time.
  TaskEntry.undated(CalendarTask task) : this._(task, task.series);

  final CalendarTask task;

  /// What it says: its date's own (changed) part, or the series'.
  final TaskPart part;

  /// Which date of a repeating task it is, as the series writes it;
  /// `null` for a task that doesn't repeat.
  final CalendarTime? date;

  /// When it is due, on this device's clock (a day: at midnight); `null`
  /// for never.
  final DateTime? due;
  final bool allDay;

  bool get done => part.done;
}

/// One row of the tasks list: an [entry] of the calendar keyed [calendar].
typedef TaskRow<K> = ({K calendar, TaskEntry entry});

/// The tasks of some calendars as the tasks list groups them, each group
/// by due time: open ones [overdue] (due before today), due [today],
/// due [later], and with [noDate]; and those [done] lately, the latest
/// first.
final class TaskList<K> {
  const TaskList({
    required this.overdue,
    required this.today,
    required this.later,
    required this.noDate,
    required this.done,
  });

  final List<TaskRow<K>> overdue;
  final List<TaskRow<K>> today;
  final List<TaskRow<K>> later;
  final List<TaskRow<K>> noDate;
  final List<TaskRow<K>> done;
}

/// How far back the tasks list looks: for a repeating task's open dates,
/// and for what was done.
const tasksBack = Duration(days: 30);

/// How far ahead the tasks list looks for a repeating task's next date.
const tasksAhead = Duration(days: 366);

/// The tasks list of [calendars] (by key) as of [today] (at midnight on
/// this device's clock): each task that doesn't repeat; of each
/// repeating one only its oldest open date of the last 30 days, else its
/// next one (up to a year ahead), so a task done daily shows once; the
/// dates and tasks done in the last 30 days (by when they were done, else
/// when due), in [TaskList.done]. Deleted and cancelled tasks are left out.
TaskList<K> taskList<K>(Map<K, Calendar> calendars, DateTime today) {
  final from = today.subtract(tasksBack);
  final to = today.add(tasksAhead);
  final rows = [
    for (final MapEntry(key: calendar, value: each) in calendars.entries)
      for (final task in each.tasks)
        for (final entry in _entriesOf(task, from, to))
          (calendar: calendar, entry: entry),
  ];
  final open = rows.where((row) => !row.entry.done);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  List<TaskRow<K>> dueIn(bool Function(DateTime due) when) =>
      open
          .where(
            (row) => switch (row.entry.due) {
              final due? => when(due),
              null => false,
            },
          )
          .toList()
        ..sort(_byDue);
  return TaskList(
    overdue: dueIn((due) => due.isBefore(today)),
    today: dueIn((due) => !due.isBefore(today) && due.isBefore(tomorrow)),
    later: dueIn((due) => !due.isBefore(tomorrow)),
    noDate: open.where((row) => row.entry.due == null).toList()..sort(_byDue),
    done: [
      for (final row in rows)
        if (row.entry.done &&
            !(row.entry.part.completed ?? row.entry.due ?? from).isBefore(from))
          row,
    ]..sort((a, b) => _byDue(b, a)),
  );
}

/// What the tasks list shows of [task], looking from [from] to [to]: an
/// open single task whenever due, a repeating one's oldest open date and
/// its done dates in the window.
Iterable<TaskEntry> _entriesOf(CalendarTask task, DateTime from, DateTime to) {
  final series = task.series;
  if (series.deleted || series.cancelled) return const [];
  if (series.from == null && !series.changesOccurrence) {
    return [TaskEntry.undated(task)];
  }
  final repeats = series.repeats || series.changesOccurrence;
  final (start, end) = repeats ? (from, to) : (_farPast, _farFuture);
  final dates = [
    for (final occurrence in occurrencesOf(task, start, end))
      if (occurrence is TaskOccurrence) TaskEntry.of(occurrence),
  ];
  return [
    ...dates.where((entry) => entry.done),
    ?dates.where((entry) => !entry.done).sorted(_entryByDue).firstOrNull,
  ];
}

/// Before and after any date a calendar holds.
final _farPast = DateTime(1);
final _farFuture = DateTime(9999);

int _byDue<K>(TaskRow<K> a, TaskRow<K> b) => _entryByDue(a.entry, b.entry);

/// By due time, no due time last; then by title.
int _entryByDue(TaskEntry a, TaskEntry b) => switch ((a.due, b.due)) {
  (final x?, final y?) when x != y => x.compareTo(y),
  (_?, null) => -1,
  (null, _?) => 1,
  _ => a.part.summary.compareTo(b.part.summary),
};
