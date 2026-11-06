import 'dart:math';

import '../model/calendar_event.dart';
import '../model/calendar_unit.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';

/// [event] stamped as edited [at]; a [first] stamp starts its `SEQUENCE`
/// at 0, else it goes one above its own and [above].
Component stamped(
  Component event,
  DateTime at, {
  bool first = false,
  int above = -1,
}) => event
    .withProperty('DTSTAMP', stampLine('DTSTAMP', at))
    .withProperty('LAST-MODIFIED', stampLine('LAST-MODIFIED', at))
    .withProperty(
      'SEQUENCE',
      ContentLine(
        'SEQUENCE',
        '${first ? 0 : max(sequenceOf(event), above) + 1}',
      ),
    );

/// [unit] stamped as edited [at] over [now], the version it replaces
/// (`null`: none), so a merge with [now]'s text keeps [unit]: every
/// component stamped, its `SEQUENCE` above both (a unit wins a merge
/// whole, so all its parts carry the stamp, untouched ones too).
CalendarUnit stampedOver(CalendarUnit unit, DateTime at, CalendarUnit? now) =>
    CalendarUnit.edited(unit.key, [
      for (final component in unit.components)
        stamped(component, at, above: _latestSequence(now)),
    ]);

/// [unit]'s text without its edit stamps (`DTSTAMP`, `LAST-MODIFIED`,
/// `SEQUENCE`), printed fresh: what two versions of it differ in beyond
/// when they were edited.
String unstampedText(CalendarUnit unit) => [
  for (final component in unit.components)
    component
        .withProperty('DTSTAMP', null)
        .withProperty('LAST-MODIFIED', null)
        .withProperty('SEQUENCE', null)
        .printed,
].join();

/// The highest `SEQUENCE` of [unit]'s components; -1 if none has one.
int _latestSequence(CalendarUnit? unit) =>
    unit?.components.map(sequenceOf).fold<int>(-1, max) ?? -1;

/// The `SEQUENCE` of [event]; -1 if it has none.
int sequenceOf(Component event) =>
    int.tryParse(event.value('SEQUENCE')?.trim() ?? '') ?? -1;

/// A deleted [event]'s marker: its id, stamps, start and title, and that
/// it is deleted.
Component markerOf(CalendarEvent event, DateTime at) {
  final series = event.series.component;
  return stamped(
    Component('VEVENT', [
      ContentLine('UID', event.uid),
      ?series.property('DTSTART'),
      ?series.property('SUMMARY'),
      ?series.property('SEQUENCE'),
      const ContentLine('STATUS', 'CANCELLED'),
      const ContentLine('X-TRUCE-DELETED', 'TRUE'),
    ]),
    at,
  );
}
