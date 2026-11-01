import 'package:truce_core/truce_core.dart';

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_unit.dart';
import '../read/values.dart';

/// How two texts of one calendar merge: unit by unit (an event with all
/// its changed occurrences), the newer edit winning whole. A unit on one
/// side only is kept: a deleted event stays as a marker, so a missing one
/// is never taken as deleted. Order: `main`'s units, then `other`'s new
/// ones; the calendar's own properties and layout are `main`'s. Never
/// changes a unit's text. Deterministic and idempotent.
final class CalendarMerge implements TextMerge {
  const CalendarMerge();

  @override
  MergeResult merge(String main, String other, {String? base}) {
    final (mains, others) = (Calendar.read(main), Calendar.read(other));
    if (mains == null || others == null) return const CantMerge();
    final bases = base == null ? null : Calendar.read(base);
    final winners = {
      for (final unit in others.units)
        if (mains.unitOf(unit.key) case final mine?)
          unit.key: newerOf(mine, unit),
    };
    return MergedText(
      mains.withUnits([
        for (final unit in others.units) winners[unit.key] ?? unit,
      ]).text,
      lost: [
        for (final unit in others.units)
          if (winners[unit.key] case final winner?
              when winner.text != unit.text &&
                  bases?.unitOf(unit.key)?.text != unit.text)
            nameOfUnit(unit),
      ],
    );
  }
}

/// The newer of two versions [a] and [b] of one unit: by its latest
/// `LAST-MODIFIED` (none is oldest), then its highest `SEQUENCE`, then
/// the smaller text, so every device picks the same.
CalendarUnit newerOf(CalendarUnit a, CalendarUnit b) {
  final (stampA, stampB) = (_stampOf(a), _stampOf(b));
  final byStamp = _compare(stampA, stampB);
  if (byStamp != 0) return byStamp > 0 ? a : b;
  return a.text.compareTo(b.text) <= 0 ? a : b;
}

typedef _Stamp = ({DateTime? modified, int sequence});

/// The latest edit stamp of any of [unit]'s components.
_Stamp _stampOf(CalendarUnit unit) =>
    unit.components.fold((modified: null, sequence: -1), (latest, component) {
      final modified = switch (component.property('LAST-MODIFIED')) {
        final line? => timeOf(line)?.wall,
        null => null,
      };
      final sequence =
          int.tryParse(component.value('SEQUENCE')?.trim() ?? '') ?? -1;
      return (
        modified: switch ((latest.modified, modified)) {
          (final a?, final b?) => a.isAfter(b) ? a : b,
          (final a, final b) => a ?? b,
        },
        sequence: sequence > latest.sequence ? sequence : latest.sequence,
      );
    });

/// Positive if [a] is newer than [b], negative if older, else 0.
int _compare(_Stamp a, _Stamp b) => switch ((a.modified, b.modified)) {
  (final x?, final y?) when x != y => x.compareTo(y),
  (_?, null) => 1,
  (null, _?) => -1,
  _ => a.sequence.compareTo(b.sequence),
};
