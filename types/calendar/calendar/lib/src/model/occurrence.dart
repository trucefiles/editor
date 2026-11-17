import 'calendar_item.dart';
import 'calendar_time.dart';
import 'item_part.dart';

/// One date of an event or a task, as it shows: [part] says what it is
/// (the series, a single item, or a changed date), from [start] to [end]
/// on this device's clock (for a task: the half hour up to its due time,
/// or its due day).
sealed class Occurrence {
  const Occurrence({required this.start, required this.end, this.recurrence});

  CalendarItem get item;
  ItemPart get part;
  final DateTime start;
  final DateTime end;

  /// Which date of its series it is, as the series writes it (its
  /// anchor, see [ItemPart.anchor]); `null` for an item that doesn't
  /// repeat.
  final CalendarTime? recurrence;

  bool get allDay => part.allDay;

  /// Whether it overlaps [from] to [to]; one with no length overlaps
  /// where it starts. The rule the calendar's occurrences are picked by.
  bool overlaps(DateTime from, DateTime to) =>
      spanOverlaps(start, end, from, to);
}

/// One date of an event.
final class EventOccurrence extends Occurrence {
  const EventOccurrence(
    this.item,
    this.part, {
    required super.start,
    required super.end,
    super.recurrence,
  });

  @override
  final CalendarEvent item;
  @override
  final EventPart part;
}

/// One date of a task, due at [end] (all day: on [start]'s day).
final class TaskOccurrence extends Occurrence {
  const TaskOccurrence(
    this.item,
    this.part, {
    required super.start,
    required super.end,
    super.recurrence,
  });

  @override
  final CalendarTask item;
  @override
  final TaskPart part;

  /// Whether this date is done.
  bool get done => part.done;

  /// When it is due, on this device's clock: its due time, or its due day
  /// at midnight.
  DateTime get due => allDay ? start : end;
}

/// Whether [start] to [end] overlaps [from] to [to]; one with no length
/// overlaps where it starts.
bool spanOverlaps(DateTime start, DateTime end, DateTime from, DateTime to) =>
    start.isBefore(to) &&
    (end.isAfter(from) || (end == start && !start.isBefore(from)));
