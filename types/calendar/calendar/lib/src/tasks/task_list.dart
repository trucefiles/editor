import 'dart:collection';

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
/// first. It keeps what each task put in it, so the next list of the
/// same day walks only the tasks that changed ([taskList]).
final class TaskList<K> {
  const TaskList._({
    required this.overdue,
    required this.today,
    required this.later,
    required this.noDate,
    required this.done,
    required this._asOf,
    required this._byTask,
  });

  final List<TaskRow<K>> overdue;
  final List<TaskRow<K>> today;
  final List<TaskRow<K>> later;
  final List<TaskRow<K>> noDate;
  final List<TaskRow<K>> done;

  /// The day it is the list of.
  final DateTime _asOf;

  /// What each task put in it, by the very task.
  final Map<CalendarTask, List<TaskEntry>> _byTask;
}

/// How far back the tasks list looks: for a repeating task's open dates,
/// and for what was done.
const tasksBack = Duration(days: 30);

/// The tasks list of [calendars] (by key) as of [today] (at midnight on
/// this device's clock): each task that doesn't repeat; of each
/// repeating one only its oldest open date of the last 30 days, else its
/// next one, so a task done daily shows once; the dates and tasks done in
/// the last 30 days (by when they were done, else when due; one done at
/// no known time counts as done long ago), in [TaskList.done]. Deleted
/// and cancelled tasks are left out.
///
/// Walking a repeating task is the costly part, so a task that is still
/// the very one it was in the list [before] of the same day keeps what it
/// put there: a change walks only the tasks it changed.
TaskList<K> taskList<K>(
  Map<K, Calendar> calendars,
  DateTime today, {
  TaskList<K>? before,
}) {
  final from = today.subtract(tasksBack);
  final kept = before?._asOf == today
      ? before!._byTask
      : const <CalendarTask, List<TaskEntry>>{};
  final byTask = LinkedHashMap<CalendarTask, List<TaskEntry>>.identity()
    ..addEntries([
      for (final calendar in calendars.values)
        for (final task in calendar.tasks)
          MapEntry(task, kept[task] ?? _entriesOf(task, from, today)),
    ]);
  final rows = [
    for (final MapEntry(key: calendar, value: each) in calendars.entries)
      for (final task in each.tasks)
        for (final entry in byTask[task]!) (calendar: calendar, entry: entry),
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
  return TaskList._(
    overdue: dueIn((due) => due.isBefore(today)),
    today: dueIn((due) => !due.isBefore(today) && due.isBefore(tomorrow)),
    later: dueIn((due) => !due.isBefore(tomorrow)),
    noDate: open.where((row) => row.entry.due == null).toList()..sort(_byDue),
    done: [
      for (final row in rows)
        if (row.entry.done &&
            switch (row.entry.part.completed ?? row.entry.due) {
              final at? => !at.isBefore(from),
              null => false,
            })
          row,
    ]..sort(_byDoneLatest),
    asOf: today,
    byTask: byTask,
  );
}

/// What the tasks list shows of [task] as of [today], looking back to
/// [from]: an open single task whenever due; of a repeating one its
/// oldest open date from [from] on and its done dates up to there.
List<TaskEntry> _entriesOf(CalendarTask task, DateTime from, DateTime today) {
  final series = task.series;
  if (series.deleted || series.cancelled) return const [];
  if (series.from == null && !series.changesOccurrence) {
    return [TaskEntry.undated(task)];
  }
  final dates = series.repeats || series.changesOccurrence
      ? _datesUpToOpen(task, from, today)
      : _entriesIn(task, _farPast, _farFuture);
  final done = dates.where((entry) => entry.done);
  return [
    // Dates done on their own; those of a series done as a whole as one.
    ...done.where((entry) => entry.part != series),
    ?done.where((entry) => entry.part == series).lastOrNull,
    ?dates.where((entry) => !entry.done).sorted(_entryByDue).firstOrNull,
  ];
}

/// [task]'s dates from [from] on, walked in spans that double in length
/// (the first up to [today]'s end), up to the span that holds an open
/// one: work grows with how far that date is, so a task that repeats
/// rarely is still found and one that repeats often isn't walked far. A
/// series done as a whole has open dates only among its changed ones,
/// so its walk ends after the last of them.
List<TaskEntry> _datesUpToOpen(
  CalendarTask task,
  DateTime from,
  DateTime today,
) {
  final last = task.series.done
      ? [today, for (final part in task.changed) ?part.to?.local].max
      : _farFuture;
  final walked = <TaskEntry>[];
  for (final span in _spans(from, today.add(const Duration(days: 1)), last)) {
    walked.addAll([
      for (final occurrence in occurrencesOf(task, span.from, span.to))
        // A date across two spans is the earlier one's.
        if (occurrence is TaskOccurrence &&
            (span.from == from || !occurrence.start.isBefore(span.from)))
          TaskEntry.of(occurrence),
    ]);
    if (walked.any((entry) => !entry.done)) break;
  }
  return walked;
}

/// Spans one after another from [from], the first to [firstEnd], each
/// after twice as long as the one before, until one reaches [last].
Iterable<({DateTime from, DateTime to})> _spans(
  DateTime from,
  DateTime firstEnd,
  DateTime last,
) sync* {
  var span = (from: from, to: firstEnd);
  while (span.from.isBefore(last)) {
    yield span;
    final length = span.to.difference(span.from) * 2;
    span = (from: span.to, to: span.to.add(length));
  }
}

/// [task]'s dates that overlap [from] to [to].
List<TaskEntry> _entriesIn(CalendarTask task, DateTime from, DateTime to) => [
  for (final occurrence in occurrencesOf(task, from, to))
    if (occurrence is TaskOccurrence) TaskEntry.of(occurrence),
];

/// Before and after any date a calendar holds.
final _farPast = DateTime(1);
final _farFuture = DateTime(9999);

int _byDue<K>(TaskRow<K> a, TaskRow<K> b) => _entryByDue(a.entry, b.entry);

/// By when done (else due), the latest first; then by title.
int _byDoneLatest<K>(TaskRow<K> a, TaskRow<K> b) {
  DateTime? doneAt(TaskEntry entry) => entry.part.completed ?? entry.due;
  return switch ((doneAt(a.entry), doneAt(b.entry))) {
    (final x?, final y?) when x != y => y.compareTo(x),
    (_?, null) => -1,
    (null, _?) => 1,
    _ => a.entry.part.summary.compareTo(b.entry.part.summary),
  };
}

/// By due time, no due time last; then by title.
int _entryByDue(TaskEntry a, TaskEntry b) => switch ((a.due, b.due)) {
  (final x?, final y?) when x != y => x.compareTo(y),
  (_?, null) => -1,
  (null, _?) => 1,
  _ => a.part.summary.compareTo(b.part.summary),
};
