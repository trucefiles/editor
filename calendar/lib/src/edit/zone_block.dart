import 'package:timezone/timezone.dart' as tz;

import '../model/calendar_time.dart';
import '../model/time_zones.dart';
import '../read/component.dart';
import '../read/content_line.dart';
import '../read/values.dart';

/// The time zone block (`VTIMEZONE`) a calendar holds for its events in
/// [zone] (an IANA name), so other apps read their times right; `null` if
/// the `timezone` data doesn't know [zone].
///
/// Own code, not a library: no maintained Dart package writes one. Built
/// from the `timezone` data only, never from today's date, so every
/// device with the same data writes the same bytes and two devices adding
/// one zone merge to one block. It covers the zone's clock changes from
/// [zoneBlocksFrom] on: one yearly rule per change where the zone keeps
/// one rule to the end of the data (2037; later years follow the rule),
/// else each change listed (e.g. Santiago, Casablanca), the last offset
/// going on after them.
Component? zoneBlock(String zone) => switch (locationOf(zone)) {
  final location? => Component('VTIMEZONE', [
    ContentLine('TZID', zone),
  ], children: _observances(location)),
  null => null,
};

/// The first year a zone block covers: fixed, so its bytes don't depend
/// on when it is written. Events before it may show an hour off in other
/// apps.
const zoneBlocksFrom = 2020;

List<Component> _observances(tz.Location location) {
  final changes = _changesOf(location);
  if (changes.isEmpty) {
    return [
      _fixed(
        location.timeZone(DateTime.utc(zoneBlocksFrom).millisecondsSinceEpoch),
      ),
    ];
  }
  final first = _changesIn(changes, zoneBlocksFrom);
  return _keepsOneRule(changes, first)
      ? [for (final change in first) _observance(change, yearly: true)]
      : [for (final change in changes) _observance(change, yearly: false)];
}

/// One change of a zone's clock: when it happens on the clock before it
/// ([wall]), and the offsets before and after.
typedef _Change = ({DateTime wall, tz.TimeZone from, tz.TimeZone to});

/// [location]'s clock changes from [zoneBlocksFrom] on, to the end of the
/// data; not the data's entries that change nothing (e.g. where it ends,
/// in 2038).
List<_Change> _changesOf(tz.Location location) {
  final from = DateTime.utc(zoneBlocksFrom).millisecondsSinceEpoch;
  return [
    for (final (index, at) in location.transitionAt.indexed)
      if (index > 0 && at >= from)
        if (_changeAt(location, index) case final change
            when !_same(change.from, change.to))
          change,
  ];
}

bool _same(tz.TimeZone a, tz.TimeZone b) =>
    a.offset == b.offset &&
    a.isDst == b.isDst &&
    a.abbreviation == b.abbreviation;

/// [location]'s clock change number [index] of its data.
_Change _changeAt(tz.Location location, int index) {
  final before = location.zones[location.transitionZone[index - 1]];
  return (
    wall: DateTime.fromMillisecondsSinceEpoch(
      location.transitionAt[index] + before.offset.inMilliseconds,
      isUtc: true,
    ),
    from: before,
    to: location.zones[location.transitionZone[index]],
  );
}

List<_Change> _changesIn(List<_Change> changes, int year) => [
  for (final change in changes)
    if (change.wall.year == year) change,
];

/// Whether every year from [zoneBlocksFrom] to the end of the data
/// repeats [first], the first year's two changes, by the same weekday
/// rule, time and offsets (a zone that stopped changing its clock
/// doesn't).
bool _keepsOneRule(List<_Change> changes, List<_Change> first) =>
    first.length == 2 &&
    [
      for (var year = zoneBlocksFrom; year <= _dataEnds; year++)
        _changesIn(changes, year),
    ].every(
      (ofYear) =>
          ofYear.length == 2 &&
          _sameRule(ofYear[0], first[0]) &&
          _sameRule(ofYear[1], first[1]),
    );

/// The last year the `timezone` data lists clock changes for.
const _dataEnds = 2037;

bool _sameRule(_Change a, _Change b) =>
    _ruleOf(a.wall) == _ruleOf(b.wall) &&
    a.wall.hour == b.wall.hour &&
    a.wall.minute == b.wall.minute &&
    _same(a.from, b.from) &&
    _same(a.to, b.to);

/// The weekday rule of [wall]: its month, its weekday, and which one of
/// that weekday in the month it is (-1 for the last).
({int month, int nth, int weekday}) _ruleOf(DateTime wall) {
  final daysInMonth = DateTime.utc(wall.year, wall.month + 1, 0).day;
  return (
    month: wall.month,
    nth: wall.day + 7 > daysInMonth ? -1 : (wall.day - 1) ~/ 7 + 1,
    weekday: wall.weekday,
  );
}

const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

Component _observance(_Change change, {required bool yearly}) {
  final rule = _ruleOf(change.wall);
  return Component(change.to.isDst ? 'DAYLIGHT' : 'STANDARD', [
    ContentLine('DTSTART', _wallText(change.wall)),
    ContentLine('TZOFFSETFROM', _offsetText(change.from.offset)),
    ContentLine('TZOFFSETTO', _offsetText(change.to.offset)),
    textLine('TZNAME', change.to.abbreviation),
    if (yearly)
      ContentLine(
        'RRULE',
        'FREQ=YEARLY;BYMONTH=${rule.month};'
            'BYDAY=${rule.nth}${_weekdays[rule.weekday - 1]}',
      ),
  ]);
}

/// A zone whose clock doesn't change from [zoneBlocksFrom] on: the
/// offset it has then, written as from 1970 (older events may differ).
Component _fixed(tz.TimeZone zone) => Component('STANDARD', [
  const ContentLine('DTSTART', '19700101T000000'),
  ContentLine('TZOFFSETFROM', _offsetText(zone.offset)),
  ContentLine('TZOFFSETTO', _offsetText(zone.offset)),
  textLine('TZNAME', zone.abbreviation),
]);

/// [wall] as a floating time (the onset on the clock before the change).
String _wallText(DateTime wall) => timeLine('DTSTART', Floating(wall)).value;

/// [offset] as written (`+0130`, `-0500`).
String _offsetText(Duration offset) {
  final minutes = offset.inMinutes.abs();
  String two(int value) => '$value'.padLeft(2, '0');
  return '${offset.isNegative ? '-' : '+'}${two(minutes ~/ 60)}'
      '${two(minutes % 60)}';
}
