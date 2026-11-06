import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:truce_core/truce_core.dart' show TextFile;

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_unit.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import 'stamp.dart';
import 'zone_block.dart';

/// What importing a calendar file came to, for the user.
sealed class ImportReport {
  const ImportReport();
}

/// The file is no calendar: not text, or not one calendar.
final class NotACalendar extends ImportReport {
  const NotACalendar();
}

/// The file is a calendar without events.
final class NoEvents extends ImportReport {
  const NoEvents();
}

/// The file's events brought in: [added] ones the calendar didn't have
/// (or had deleted), [updated] ones it held another version of. Both
/// none: the calendar had them all already.
final class EventsImported extends ImportReport {
  const EventsImported({required this.added, required this.updated});

  final int added;
  final int updated;
}

/// A calendar file's events imported into a calendar: what the
/// [calendar] becomes, the units it [written] (each changed), and the
/// [report].
typedef CalendarImport = ({
  Calendar calendar,
  List<UnitKey> written,
  ImportReport report,
});

/// [calendar] with the events of the calendar file [bytes] imported at
/// [at], as the user's own edit then: each event the file holds is put
/// in as the file has it, stamped as edited [at] (so a merge with an
/// older text keeps it), where the calendar lacks it, deleted it, or
/// holds another version of it (stamps aside). Only events come in: not
/// the file's name, properties, other components, or deleted events'
/// markers (a file brings events, not deletes). An event without `UID`
/// (invalid, but some apps write them) gets one made from its text, so
/// importing it again finds it. Each zone a written event names that the
/// calendar has no block for gets the file's block, else this app's
/// ([zoneUnit]).
CalendarImport importInto(Calendar calendar, Uint8List bytes, DateTime at) {
  final file = switch (TextFile.decode(bytes)) {
    final decoded? => Calendar.read(decoded.text),
    null => null,
  };
  final events = [
    for (final unit in file?.units ?? const <CalendarUnit>[]) ?_event(unit),
  ];
  if (file == null || events.isEmpty) {
    return (
      calendar: calendar,
      written: const [],
      report: file == null ? const NotACalendar() : const NoEvents(),
    );
  }
  final changed = [
    // One event per key: a file may hold one UID-less event twice.
    for (final event in {for (final event in events) event.key: event}.values)
      ?_change(event, calendar.unitOf(event.key), at),
  ];
  final taken = [for (final (:event, mine: _) in changed) event];
  final zones = [
    for (final zone in {for (final unit in taken) ...unit.zonesNamed})
      if (!calendar.zones.contains(zone))
        ?(file.unitOf(ZoneKey(zone)) ?? zoneUnit(zone)),
  ];
  final written = [...taken, ...zones];
  final added = changed.where((side) => _isNew(side.mine)).length;
  return (
    calendar: calendar.withUnits(written),
    written: [for (final unit in written) unit.key],
    report: EventsImported(added: added, updated: changed.length - added),
  );
}

/// The file's [event] as written over [mine], the calendar's version
/// (`null`: none), stamped [at], with [mine]; `null` if the calendar
/// holds it already (edit stamps aside).
({CalendarUnit event, CalendarUnit? mine})? _change(
  CalendarUnit event,
  CalendarUnit? mine,
  DateTime at,
) => switch (_over(event, mine)) {
  final over when mine != null && unstampedText(mine) == unstampedText(over) =>
    null,
  final over => (event: stampedOver(over, at, mine), mine: mine),
};

/// What the calendar holds of the file's [event] once imported over
/// [mine], its version here (`null`: none): the file's whole event; but
/// a file of changed occurrences only (e.g. an invite for one date of a
/// series), over an event held here (a series, or changed dates only),
/// changes only those occurrences in it, each in place of the one for
/// the same date, the rest added.
CalendarUnit _over(CalendarUnit event, CalendarUnit? mine) {
  final ours = mine == null ? null : CalendarEvent.of(mine);
  final dates = {
    for (final component in event.components)
      EventPart(component).recurrenceId?.local: component,
  };
  if (ours == null || ours.series.deleted || dates.containsKey(null)) {
    return event;
  }
  final parts = [
    for (final component in mine!.components)
      EventPart(component).recurrenceId?.local,
  ];
  final held = parts.toSet();
  return CalendarUnit.edited(event.key, [
    for (final (index, component) in mine.components.indexed)
      dates[parts[index]] ?? component,
    for (final MapEntry(:key, :value) in dates.entries)
      if (!held.contains(key)) value,
  ]);
}

/// Whether an event the calendar holds as [mine] is new to the user: it
/// has none, or only a deleted event's marker.
bool _isNew(CalendarUnit? mine) =>
    mine == null || (CalendarEvent.of(mine)?.series.deleted ?? false);

/// [unit] as imported if it is an event: as it is, or given a `UID` made
/// from its text if it has none; `null` for any other unit, and for a
/// deleted event's marker.
CalendarUnit? _event(CalendarUnit unit) {
  final event = switch ((unit.key, unit.components)) {
    (UidKey(component: 'VEVENT'), _) => unit,
    (TextKey(), [final Component component]) when component.name == 'VEVENT' =>
      _withUid(component, _uidOf(unstampedText(unit))),
    _ => null,
  };
  return switch (event) {
    final event? when !CalendarEvent.of(event)!.series.deleted => event,
    _ => null,
  };
}

CalendarUnit _withUid(Component event, String uid) => CalendarUnit.edited(
  UidKey.event(uid),
  [event.withProperty('UID', ContentLine('UID', uid))],
);

/// A `UID` for an event that has none, made from its [text] without
/// edit stamps: the same for the same event, on every device, whenever
/// it was exported.
String _uidOf(String text) =>
    '${sha256.convert(utf8.encode(text)).toString().substring(0, 32)}@truce';
