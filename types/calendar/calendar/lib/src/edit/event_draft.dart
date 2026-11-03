import 'package:collection/collection.dart';

import '../model/calendar_event.dart';
import '../model/calendar_time.dart';
import '../model/event_color.dart';
import '../model/health_entry.dart';
import '../model/repeat.dart';
import '../model/wall_on.dart';

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
    this.color,
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
        color: part.color,
      );

  /// What [event]'s occurrence at [occurrence] says now, to start a form
  /// from: its changed one, else the series at that time (it doesn't
  /// repeat).
  factory EventDraft.at(CalendarEvent event, CalendarTime occurrence) {
    if (event.changedAt(occurrence) case final changed?) {
      return EventDraft.of(changed);
    }
    final series = EventDraft.of(event.series);
    final length = lengthOn(series.start, series.end);
    return series.occurrenceAt(
      occurrence,
      occurrence.at(occurrence.wall.add(length)),
    );
  }

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

  /// Its own color; `null` for none (it shows in its calendar's).
  final EventColor? color;

  /// This draft for one occurrence, from [start] to [end]: it doesn't
  /// repeat.
  EventDraft occurrenceAt(CalendarTime start, CalendarTime end) => EventDraft(
    summary: summary,
    start: start,
    end: end,
    description: description,
    location: location,
    alerts: alerts,
    health: health,
    color: color,
  );

  /// What is to be written when a form started from [from] ends as this
  /// draft, while the event became [now] meanwhile (e.g. changed on
  /// another device): what the user changed as this draft says, the rest
  /// as [now] says. Start and end count as one.
  EventDraft over(EventDraft from, EventDraft now) {
    T changed<T>(T Function(EventDraft draft) field) =>
        field(this) != field(from) ? field(this) : field(now);
    final timesChanged = start != from.start || end != from.end;
    return EventDraft(
      summary: changed((draft) => draft.summary),
      start: timesChanged ? start : now.start,
      end: timesChanged ? end : now.end,
      description: changed((draft) => draft.description),
      location: changed((draft) => draft.location),
      repeat: changed((draft) => draft.repeat),
      alerts: const ListEquality<Duration>().equals(alerts, from.alerts)
          ? now.alerts
          : alerts,
      health: changed((draft) => draft.health),
      color: changed((draft) => draft.color),
    );
  }

  /// Whether [alerts] are those of [part].
  bool sameAlertsAs(EventPart part) =>
      const ListEquality<Duration>().equals(alerts, part.alerts);
}
