import 'package:collection/collection.dart';

import '../read/component.dart';
import '../read/content_line.dart';
import 'calendar_event.dart';
import 'calendar_unit.dart';

/// One calendar file, read: the lines up to its first unit ([head]: the
/// calendar's own properties), its [units] in order, and the lines from
/// its end on ([tail]). Prints back byte for byte, each unit's parts where
/// they were ([_layout]); an edit replaces whole units, an edited unit
/// printed where its first part was. Immutable; questions are lookups on
/// it.
final class Calendar {
  /// A calendar printing each unit's parts together, in order.
  Calendar(String head, List<CalendarUnit> units, String tail)
    : this._(head, units, tail, [
        for (final unit in units)
          for (final index in Iterable<int>.generate(unit.parts.length))
            (key: unit.key, part: index),
      ]);

  Calendar._(this.head, this.units, this.tail, this._layout)
    : _byKey = {for (final unit in units) unit.key: unit};

  /// The text up to the first unit: `BEGIN:VCALENDAR` and the calendar's
  /// properties.
  final String head;
  final List<CalendarUnit> units;

  /// `END:VCALENDAR` and anything after it.
  final String tail;

  final Map<UnitKey, CalendarUnit> _byKey;

  /// Where each part of each unit prints, in order.
  final List<_Slot> _layout;

  /// The calendar in [text] (`\n` line breaks); `null` if it is none.
  static Calendar? read(String text) {
    final lines = logicalLines(text);
    final begin = lines.indexWhere(
      (line) => line.unfolded.trim().toUpperCase() == 'BEGIN:VCALENDAR',
    );
    if (begin < 0 ||
        lines.take(begin).any((line) => line.unfolded.trim().isNotEmpty)) {
      return null;
    }
    final end = lines.lastIndexWhere(
      (line) => line.unfolded.trim().toUpperCase() == 'END:VCALENDAR',
    );
    if (end <= begin) return null;
    final inside = lines.sublist(begin + 1, end);
    final firstUnit = inside.indexWhere(_begins);
    final headCount = firstUnit < 0 ? inside.length : firstUnit;
    final blocks = _blocks(inside.sublist(headCount));
    if (blocks == null) return null;
    final (:units, :layout) = _units(blocks);
    return Calendar._(
      _textOf(lines.sublist(0, begin + 1 + headCount)),
      units,
      _textOf(lines.sublist(end)),
      layout,
    );
  }

  /// The calendar's text.
  late final String text = [
    head,
    for (final (:key, :part) in _layout)
      if (_byKey[key]!.parts case final parts when part < parts.length)
        parts[part],
    tail,
  ].join();

  /// The unit [key]; `null` if there is none.
  CalendarUnit? unitOf(UnitKey key) => _byKey[key];

  /// The calendar's events, deleted ones' markers among them, in order.
  late final List<CalendarEvent> events = [
    for (final unit in units) ?CalendarEvent.of(unit),
  ];

  late final Map<String, CalendarEvent> _eventsByUid = {
    for (final event in events) event.uid: event,
  };

  /// The event [uid]; `null` if there is none.
  CalendarEvent? eventOf(String uid) => _eventsByUid[uid];

  /// The calendar's own properties.
  late final List<ContentLine> properties = [
    for (final line in logicalLines(head).skip(1))
      ?ContentLine.parse(line.unfolded, raw: line.raw),
  ];

  /// The calendar's name, as other apps show it; empty if it has none.
  late final String name = unescapeText(
    properties.firstWhereOrNull((line) => line.name == 'X-WR-CALNAME')?.value ??
        '',
  );

  /// Whether it is a health calendar (shown with its cycle).
  late final bool isHealth = properties.any(
    (line) =>
        line.name == healthFlag.name &&
        line.value.toUpperCase() == healthFlag.value,
  );

  /// This calendar with [unit] in place of the one with its key, or added
  /// at the end.
  Calendar withUnit(CalendarUnit unit) => _byKey.containsKey(unit.key)
      ? Calendar._(
          head,
          [for (final each in units) each.key == unit.key ? unit : each],
          tail,
          _layout,
        )
      : Calendar._(
          head,
          [...units, unit],
          tail,
          [
            ..._layout,
            for (final index in Iterable<int>.generate(unit.parts.length))
              (key: unit.key, part: index),
          ],
        );
}

/// The calendar property that makes a calendar a health calendar.
const healthFlag = ContentLine('X-TRUCE-CALENDAR', 'HEALTH');

/// The text of a new calendar named [name], a health calendar if
/// [health]: no events yet.
String newCalendarText(String name, {bool health = false}) => [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//Truce Editor//Calendar//EN',
  ContentLine('X-WR-CALNAME', escapeText(name)).printed,
  if (health) healthFlag.printed,
  'END:VCALENDAR',
  '',
].join('\n');

typedef _Line = ({String unfolded, String raw});

/// One place in the file: part [part] of the unit [key].
typedef _Slot = ({UnitKey key, int part});

bool _begins(_Line line) => line.unfolded.toUpperCase().startsWith('BEGIN:');

String _textOf(List<_Line> lines) =>
    lines.map((line) => '${line.raw}\n').join();

/// [lines] split into components (each from its `BEGIN` to its `END`)
/// and runs of other lines between them; `null` if a component doesn't
/// end.
List<List<_Line>>? _blocks(List<_Line> lines) {
  final blocks = <List<_Line>>[];
  var rest = lines;
  while (rest.isNotEmpty) {
    if (_begins(rest.first)) {
      final end = _endOf(rest);
      if (end < 0) return null;
      blocks.add(rest.sublist(0, end + 1));
      rest = rest.sublist(end + 1);
    } else {
      final next = rest.indexWhere(_begins);
      final count = next < 0 ? rest.length : next;
      blocks.add(rest.sublist(0, count));
      rest = rest.sublist(count);
    }
  }
  return blocks;
}

/// Where the component [lines] begin with ends; -1 if it doesn't.
int _endOf(List<_Line> lines) {
  final name = lines.first.unfolded.substring('BEGIN:'.length).trim();
  final (begin, end) = ('BEGIN:$name'.toUpperCase(), 'END:$name'.toUpperCase());
  var depth = 0;
  for (final (index, line) in lines.indexed) {
    final upper = line.unfolded.trim().toUpperCase();
    if (upper == begin) depth++;
    if (upper == end && --depth == 0) return index;
  }
  return -1;
}

/// [blocks] as units: events with a `UID` grouped by it, in the order of
/// their first block; every other block a unit of its own text. And
/// where each block was.
({List<CalendarUnit> units, List<_Slot> layout}) _units(
  List<List<_Line>> blocks,
) {
  final parts = [
    for (final block in blocks)
      (
        text: _textOf(block),
        component: _begins(block.first) ? readComponent(block) : null,
      ),
  ];
  final byUid = groupBy([
    for (final (index, part) in parts.indexed)
      if (_uidOf(part.component) != null) index,
  ], (int index) => _uidOf(parts[index].component)!);
  final textsSeen = <String, int>{};
  final units = <CalendarUnit>[];
  final layout = <_Slot>[];
  for (final (index, part) in parts.indexed) {
    final uid = _uidOf(part.component);
    if (uid != null) {
      final group = byUid[uid]!;
      if (group.first == index) {
        units.add(
          CalendarUnit.read(
            UidKey(uid),
            [for (final at in group) parts[at].text],
            [for (final at in group) parts[at].component!],
          ),
        );
      }
      layout.add((key: UidKey(uid), part: group.indexOf(index)));
    } else {
      final nth = textsSeen.update(part.text, (n) => n + 1, ifAbsent: () => 0);
      final key = TextKey(part.text, nth);
      units.add(CalendarUnit.read(key, [part.text], [?part.component]));
      layout.add((key: key, part: 0));
    }
  }
  return (units: units, layout: layout);
}

/// The `UID` of [component] if it is an event that has one.
String? _uidOf(Component? component) => switch (component) {
  Component(name: 'VEVENT') => component.value('UID')?.trim(),
  _ => null,
};
