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
  Calendar._(this.head, this.units, this.tail, this._layout);

  /// The text up to the first unit: `BEGIN:VCALENDAR` and the calendar's
  /// properties.
  final String head;
  final List<CalendarUnit> units;

  /// `END:VCALENDAR` and anything after it.
  final String tail;

  late final Map<UnitKey, CalendarUnit> _byKey = {
    for (final unit in units) unit.key: unit,
  };

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
    final tail = _textOf(lines.sublist(end));
    return Calendar._(
      _textOf(lines.sublist(0, begin + 1 + headCount)),
      units,
      // Its last line break only if the text has one.
      text.endsWith('\n') ? tail : tail.substring(0, tail.length - 1),
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

  /// Whether [other] holds the very units this one does (as [named]
  /// keeps them), so their events are the same.
  bool holdsSameUnitsAs(Calendar other) => identical(units, other.units);

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

  /// The time zones it holds a block for.
  late final Set<String> zones = {
    for (final unit in units)
      if (unit.key case ZoneKey(:final zone)) zone,
  };

  /// The calendar's own properties.
  late final List<ContentLine> properties = [
    for (final line in logicalLines(head).skip(1))
      ?ContentLine.parse(line.unfolded, raw: line.raw),
  ];

  /// The calendar's name, as other apps show it; empty if it has none.
  late final String name = unescapeText(
    properties.firstWhereOrNull((line) => line.name == _nameProperty)?.value ??
        '',
  );

  /// Whether it is a health calendar (shown with its cycle).
  late final bool isHealth = properties.any(
    (line) =>
        line.name == healthFlag.name &&
        line.value.toUpperCase() == healthFlag.value,
  );

  /// This calendar named [name] (none if empty): only its name line
  /// changes, written in place of the old one, or as the last of its own
  /// properties if it had none; itself if it is named so already.
  Calendar named(String name) {
    if (name == this.name) return this;
    final old = properties.firstWhereOrNull(
      (line) => line.name == _nameProperty,
    );
    final written = [?_nameLine(name, old)].map((line) => '${line.printed}\n');
    return Calendar._(
      switch (old?.raw) {
        // After the line before it, so no other line's end matches.
        final raw? => head.replaceFirst('\n$raw\n', '\n${written.join()}'),
        null => '$head${written.join()}',
      },
      units,
      tail,
      _layout,
    );
  }

  /// This calendar with [unit] in place of the one with its key, or added
  /// at the end.
  Calendar withUnit(CalendarUnit unit) => withUnits([unit]);

  /// This calendar with each of [changes] in place of the unit with its
  /// key, where it was; those it doesn't have added at the end, in order.
  Calendar withUnits(Iterable<CalendarUnit> changes) {
    if (changes.isEmpty) return this;
    final byKey = {for (final unit in changes) unit.key: _fitted(unit)};
    final added = [
      for (final unit in byKey.values)
        if (!_byKey.containsKey(unit.key)) unit,
    ];
    return Calendar._(
      head,
      [for (final each in units) byKey[each.key] ?? each, ...added],
      tail,
      [
        ..._layout,
        for (final unit in added)
          for (final index in Iterable<int>.generate(unit.parts.length))
            (key: unit.key, part: index),
      ],
    );
  }

  /// [unit] as it fits the places of the unit it replaces: its parts
  /// there, or, if it has not as many, its whole text where that unit's
  /// first part was.
  CalendarUnit _fitted(CalendarUnit unit) => switch (_byKey[unit.key]) {
    final old? when old.parts.length != unit.parts.length => CalendarUnit.read(
      unit.key,
      [unit.text],
      unit.components,
    ),
    _ => unit,
  };
}

/// The line that names a calendar [name]; `null` for an empty name,
/// which a calendar holds as no line.
/// The name line for [name] (none if empty), keeping the parameters of
/// the [old] one.
ContentLine? _nameLine(String name, [ContentLine? old]) => name.isEmpty
    ? null
    : ContentLine(
        _nameProperty,
        escapeText(name),
        params: old?.params ?? const {},
      );

const _nameProperty = 'X-WR-CALNAME';

/// What a calendar is called by its kind: as the user picks a new one,
/// and as one without a name is named.
String kindName({required bool health}) =>
    health ? 'Health calendar' : 'Calendar';

/// The calendar property that makes a calendar a health calendar.
const healthFlag = ContentLine('X-TRUCE-CALENDAR', 'HEALTH');

/// The text of a new calendar named [name] (none if empty), a health
/// calendar if [health]: no events yet.
String newCalendarText(String name, {bool health = false}) => [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//Truce Editor//Calendar//EN',
  ?_nameLine(name)?.printed,
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
/// end. One pass over [lines]: each block is a range of them.
List<List<_Line>>? _blocks(List<_Line> lines) {
  final blocks = <List<_Line>>[];
  var start = 0;
  while (start < lines.length) {
    final end = _begins(lines[start])
        ? _endOf(lines, start) + 1
        : _nextBegin(lines, start);
    // A component that doesn't end.
    if (end <= start) return null;
    blocks.add(lines.sublist(start, end));
    start = end;
  }
  return blocks;
}

/// Where the next component after [from] in [lines] begins; their
/// length if none does.
int _nextBegin(List<_Line> lines, int from) {
  final next = lines.indexWhere(_begins, from + 1);
  return next < 0 ? lines.length : next;
}

/// Where the component that begins at [start] in [lines] ends; -1 if it
/// doesn't.
int _endOf(List<_Line> lines, int start) {
  final name = lines[start].unfolded.substring('BEGIN:'.length).trim();
  final (begin, end) = ('BEGIN:$name'.toUpperCase(), 'END:$name'.toUpperCase());
  var depth = 0;
  for (var index = start; index < lines.length; index++) {
    final upper = lines[index].unfolded.trim().toUpperCase();
    if (upper == begin) depth++;
    if (upper == end && --depth == 0) return index;
  }
  return -1;
}

/// [blocks] as units: components with a `UID` grouped by their kind and
/// it, and time zone blocks by their `TZID`, in the order of their first
/// block; every other block a unit of its own text. And where each block
/// was.
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
  final byKey = groupBy([
    for (final (index, part) in parts.indexed)
      if (_keyOf(part.component) != null) index,
  ], (int index) => _keyOf(parts[index].component)!);
  final textsSeen = <String, int>{};
  final units = <CalendarUnit>[];
  final layout = <_Slot>[];
  for (final (index, part) in parts.indexed) {
    if (_keyOf(part.component) case final key?) {
      final group = byKey[key]!;
      if (group.first == index) {
        units.add(
          CalendarUnit.read(
            key,
            [for (final at in group) parts[at].text],
            [for (final at in group) parts[at].component!],
          ),
        );
      }
      layout.add((key: key, part: group.indexOf(index)));
    } else {
      final nth = textsSeen.update(part.text, (n) => n + 1, ifAbsent: () => 0);
      final key = TextKey(part.text, nth);
      units.add(CalendarUnit.read(key, [part.text], [?part.component]));
      layout.add((key: key, part: 0));
    }
  }
  return (units: units, layout: layout);
}

/// The key that groups [component] with others: its `TZID` for a time
/// zone block, its kind and `UID` for any other that has one (events,
/// tasks, journal entries); `null` for the rest.
UnitKey? _keyOf(Component? component) => switch (component) {
  Component(name: 'VTIMEZONE') => switch (component.value('TZID')?.trim()) {
    final zone? => ZoneKey(zone),
    null => null,
  },
  Component(:final name) => switch (component.value('UID')?.trim()) {
    final uid? => UidKey(name, uid),
    null => null,
  },
  null => null,
};
