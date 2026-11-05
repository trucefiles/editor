import 'dart:math';

import '../model/calendar_event.dart';
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
