import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:truce_core/truce_core.dart' show TextFile;

import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_unit.dart';
import '../model/item_part.dart';
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

/// The file is a calendar without events or tasks.
final class NothingToImport extends ImportReport {
  const NothingToImport();
}

/// The file's events and tasks brought in: [added] ones the calendar
/// didn't have (or had deleted), [updated] ones it held another version
/// of; [tasks] of all those are tasks. Both none: the calendar had them
/// all already.
final class ItemsImported extends ImportReport {
  const ItemsImported({
    required this.added,
    required this.updated,
    this.tasks = 0,
  });

  final int added;
  final int updated;
  final int tasks;
}

/// A calendar file's events and tasks imported into a calendar: what the
/// [calendar] becomes, the units it [written] (each changed), and the
/// [report].
typedef CalendarImport = ({
  Calendar calendar,
  List<UnitKey> written,
  ImportReport report,
});

/// [calendar] with the events and tasks of the calendar file [bytes]
/// imported at [at], as the user's own edit then: each item the file
/// holds is put in as the file has it, stamped as edited [at] (so a
/// merge with an older text keeps it), where the calendar lacks it,
/// deleted it, or holds another version of it (stamps aside). Only
/// events and tasks come in: not the file's name, properties, other
/// components, or deleted items' markers (a file brings items, not
/// deletes). An item without `UID` (invalid, but some apps write them)
/// gets one made from its text, so importing it again finds it. Each
/// zone a written item names that the calendar has no block for gets the
/// file's block, else this app's ([zoneUnit]).
CalendarImport importInto(Calendar calendar, Uint8List bytes, DateTime at) {
  final file = switch (TextFile.decode(bytes)) {
    final decoded? => Calendar.read(decoded.text),
    null => null,
  };
  final items = [
    for (final unit in file?.units ?? const <CalendarUnit>[]) ?_item(unit),
  ];
  if (file == null || items.isEmpty) {
    return (
      calendar: calendar,
      written: const [],
      report: file == null ? const NotACalendar() : const NothingToImport(),
    );
  }
  final changed = [
    // One item per key: a file may hold one UID-less item twice.
    for (final item in {for (final item in items) item.key: item}.values)
      ?_change(item, calendar.unitOf(item.key), at),
  ];
  final taken = [for (final (:item, mine: _) in changed) item];
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
    report: ItemsImported(
      added: added,
      updated: changed.length - added,
      tasks: taken.where((unit) => unit.item is CalendarTask).length,
    ),
  );
}

/// The file's [item] as written over [mine], the calendar's version
/// (`null`: none), stamped [at], with [mine]; `null` if the calendar
/// holds it already (edit stamps aside).
({CalendarUnit item, CalendarUnit? mine})? _change(
  CalendarUnit item,
  CalendarUnit? mine,
  DateTime at,
) => switch (_over(item, mine)) {
  final over when mine != null && unstampedText(mine) == unstampedText(over) =>
    null,
  final over => (item: stampedOver(over, at, mine), mine: mine),
};

/// What the calendar holds of the file's [item] once imported over
/// [mine], its version here (`null`: none): the file's whole item; but
/// a file of changed dates only (e.g. an invite for one date of a
/// series), over an item held here (a series, or changed dates only),
/// changes only those dates in it, each in place of the one for the same
/// date, the rest added; one whose date can't be read is left out, as it
/// names no date.
CalendarUnit _over(CalendarUnit item, CalendarUnit? mine) {
  final ours = mine?.item;
  final parts = item.components.map(ItemPart.of).toList();
  if (ours == null ||
      ours.series.deleted ||
      !parts.every((part) => part.changesOccurrence)) {
    return item;
  }
  final dates = {
    for (final part in parts)
      if (part.recurrenceId case final date?) date.local: part.component,
  };
  final ourDates = [
    for (final component in mine!.components)
      ItemPart.of(component).recurrenceId?.local,
  ];
  final held = ourDates.toSet();
  return CalendarUnit.edited(item.key, [
    for (final (index, component) in mine.components.indexed)
      dates[ourDates[index]] ?? component,
    for (final MapEntry(:key, :value) in dates.entries)
      if (!held.contains(key)) value,
  ]);
}

/// Whether an item the calendar holds as [mine] is new to the user: it
/// has none, or only a deleted item's marker.
bool _isNew(CalendarUnit? mine) =>
    mine == null || (mine.item?.series.deleted ?? false);

/// [unit] as imported if it is an event or a task: as it is, or given a
/// `UID` made from its text if it has none; `null` for any other unit,
/// and for a deleted item's marker.
CalendarUnit? _item(CalendarUnit unit) {
  final item = switch ((unit.key, unit.components)) {
    (UidKey(kind: _?), _) => unit,
    (TextKey(), [final Component component])
        when ItemKind.named(component.name) != null =>
      _withUid(component, _uidOf(unstampedText(unit))),
    _ => null,
  };
  return switch (item) {
    final item? when !item.item!.series.deleted => item,
    _ => null,
  };
}

CalendarUnit _withUid(Component item, String uid) => CalendarUnit.edited(
  UidKey(item.name, uid),
  [item.withProperty('UID', ContentLine('UID', uid))],
);

/// A `UID` for an item that has none, made from its [text] without
/// edit stamps: the same for the same item, on every device, whenever
/// it was exported.
String _uidOf(String text) =>
    '${sha256.convert(utf8.encode(text)).toString().substring(0, 32)}@truce';
