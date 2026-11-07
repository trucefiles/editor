import 'package:collection/collection.dart';

import '../read/content_line.dart';

/// A calendar's head: its [text] from `BEGIN:VCALENDAR` up to its first
/// unit, which holds the calendar's own properties (its name, its kind).
/// Immutable; each answer is worked out when first asked.
final class CalendarHead {
  CalendarHead(this.text);

  /// The head of the calendar in [text] (`\n` line breaks), found without
  /// reading on past it, so a calendar's name is known without reading
  /// its events; `null` if [text] starts no calendar.
  static CalendarHead? read(String text) =>
      switch (_bounds.allMatches(text).take(2).toList()) {
        [final begin, ...final rest]
            when begin[0]!.trim().toUpperCase() == 'BEGIN:VCALENDAR' &&
                text.substring(0, begin.start).trim().isEmpty =>
          CalendarHead(
            text.substring(begin.start, rest.firstOrNull?.start ?? text.length),
          ),
        _ => null,
      };

  final String text;

  /// The calendar's own properties.
  late final List<ContentLine> properties = [
    for (final line in logicalLines(text).skip(1))
      ?ContentLine.parse(line.unfolded, raw: line.raw),
  ];

  /// The line naming the calendar, as other apps read it; `null` if it
  /// has none.
  late final ContentLine? nameLine = properties.firstWhereOrNull(
    (line) => line.name == nameProperty,
  );

  /// The calendar's name, as other apps show it; empty if it has none.
  late final String name = unescapeText(nameLine?.value ?? '');

  /// The name the standard's `NAME` property gives it (RFC 7986), which
  /// some apps write; read only, never written. Empty if it has none.
  late final String standardName = unescapeText(
    properties.firstWhereOrNull((line) => line.name == 'NAME')?.value ?? '',
  ).trim();

  /// The name it shows under: its [name], else its [standardName]; empty
  /// if it has neither.
  late final String shownName = switch (name.trim()) {
    '' => standardName,
    final name => name,
  };

  /// Whether it is a health calendar (shown with its cycle).
  late final bool isHealth = properties.any(
    (line) =>
        line.name == healthFlag.name &&
        line.value.toUpperCase() == healthFlag.value,
  );
}

/// The property that names a calendar, as other apps read it.
const nameProperty = 'X-WR-CALNAME';

/// The calendar property that makes a calendar a health calendar.
const healthFlag = ContentLine('X-TRUCE-CALENDAR', 'HEALTH');

/// A line that begins or ends a component.
final _bounds = RegExp(
  r'^(BEGIN|END):.*$',
  multiLine: true,
  caseSensitive: false,
);
