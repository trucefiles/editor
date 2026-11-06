import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:truce_core/truce_core.dart' show TextFile;

import '../merge/calendar_merge.dart';
import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_unit.dart';
import '../read/component.dart';
import '../read/content_line.dart';
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

/// The file's events merged in: [added] ones the calendar didn't have,
/// [updated] ones the file held a newer version of; [kept] names those
/// the calendar held a newer version of, kept as they were, and
/// [deletedHere] those deleted here later, which stay deleted. All none:
/// the calendar had them all already.
final class EventsImported extends ImportReport {
  const EventsImported({
    required this.added,
    required this.updated,
    required this.kept,
    required this.deletedHere,
  });

  final int added;
  final int updated;
  final List<String> kept;
  final List<String> deletedHere;
}

/// A calendar file's events imported into a calendar: what the
/// [calendar] becomes, the units it [written] (each changed), and the
/// [report].
typedef CalendarImport = ({
  Calendar calendar,
  List<UnitKey> written,
  ImportReport report,
});

/// [calendar] with the events of the calendar file [bytes] merged in,
/// each as a merge without base keeps it ([mergedUnit]): one the
/// calendar lacks is added, one it has is replaced only by a newer edit.
/// Only events come in: not the file's name, properties, other
/// components, or deleted events' markers (a file brings events, not
/// deletes). An event without `UID` (invalid, but some apps write them)
/// gets one made from its text, so importing it again finds it. Each zone
/// a written event names that the calendar has no block for gets the
/// file's block, else this app's ([zoneUnit]). An imported event keeps
/// its text, but for a `UID` added.
CalendarImport importInto(Calendar calendar, Uint8List bytes) {
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
  final sides = [
    for (final event in events)
      (event: event, came: _cameOf(event, calendar.unitOf(event.key))),
  ];
  final taken = [
    for (final (:event, :came) in sides)
      if (came == _Came.added || came == _Came.updated) event,
  ];
  final zones = [
    for (final zone in {for (final unit in taken) ...unit.zonesNamed})
      if (!calendar.zones.contains(zone))
        ?(file.unitOf(ZoneKey(zone)) ?? zoneUnit(zone)),
  ];
  final written = [...taken, ...zones];
  int count(_Came kind) => sides.where((side) => side.came == kind).length;
  List<String> names(_Came kind) => [
    for (final (:event, :came) in sides)
      if (came == kind) nameOfUnit(calendar.unitOf(event.key)!),
  ];
  return (
    calendar: calendar.withUnits(written),
    written: [for (final unit in written) unit.key],
    report: EventsImported(
      added: count(_Came.added),
      updated: count(_Came.updated),
      kept: names(_Came.kept),
      deletedHere: names(_Came.deletedHere),
    ),
  );
}

/// How an imported event comes into a calendar.
enum _Came {
  /// The calendar didn't have it.
  added,

  /// The file's version is newer.
  updated,

  /// The calendar's version is newer, kept as it was.
  kept,

  /// It was deleted here later, and stays deleted.
  deletedHere,

  /// The calendar has just this version.
  same,
}

/// How [theirs] comes into a calendar that holds [mine] of it (`null`:
/// none).
_Came _cameOf(CalendarUnit theirs, CalendarUnit? mine) => switch (mine) {
  null => _Came.added,
  _ when mine.text == theirs.text => _Came.same,
  _ when mergedUnit(mine, theirs).text == mine.text =>
    CalendarEvent.of(mine)?.series.deleted ?? false
        ? _Came.deletedHere
        : _Came.kept,
  _ => _Came.updated,
};

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
