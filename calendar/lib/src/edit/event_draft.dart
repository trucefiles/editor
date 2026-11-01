import 'package:collection/collection.dart';

import '../model/calendar_event.dart';
import '../model/calendar_time.dart';
import '../model/health_entry.dart';
import '../model/repeat.dart';

/// What an event is to be, as the event or health form states it: never
/// file text. An edit writes only what differs from the event it goes
/// over; everything else of it stays as it was.
final class EventDraft {
  const EventDraft({
    required this.summary,
    required this.start,
    required this.end,
    this.description = '',
    this.location = '',
    this.repeat,
    this.alerts = const [],
    this.health,
  });

  /// A health [entry] on [day], with an optional [note].
  EventDraft.health(HealthEntry entry, DateTime day, {String note = ''})
    : this(
        summary: entry.summary,
        start: AllDay(day),
        end: AllDay(day.add(const Duration(days: 1))),
        description: note,
        health: entry,
      );

  /// What [part] says now, to start a form from.
  EventDraft.of(EventPart part)
    : this(
        summary: part.summary,
        start: part.start!,
        end: part.end!,
        description: part.description,
        location: part.location,
        repeat: part.repeat,
        alerts: part.alerts,
        health: part.health,
      );

  final String summary;
  final String description;
  final String location;
  final CalendarTime start;

  /// When it ends; for a day, the day after its last.
  final CalendarTime end;
  final Repeat? repeat;

  /// When its alerts come, before the start.
  final List<Duration> alerts;
  final HealthEntry? health;

  /// Whether [alerts] are those of [part].
  bool sameAlertsAs(EventPart part) =>
      const ListEquality<Duration>().equals(alerts, part.alerts);
}
