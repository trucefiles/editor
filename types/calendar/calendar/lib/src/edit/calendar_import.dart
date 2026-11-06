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
    for (final event in events)
      if (calendar.unitOf(event.key) case final mine
          when mine == null || unstampedText(mine) != unstampedText(event))
        (event: stampedOver(event, at, mine), mine: mine),
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
      _withUid(component, _uidOf(unit.text)),
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

/// A `UID` for an event that has none, made from its [text]: the same
/// for the same text, on every device.
String _uidOf(String text) =>
    '${sha256.convert(utf8.encode(text)).toString().substring(0, 32)}@truce';
