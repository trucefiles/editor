import 'package:truce_core/truce_core.dart';

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_unit.dart';
import '../read/component.dart';
import '../read/values.dart';

/// How two texts of one calendar merge: unit by unit (an event with all
/// its changed occurrences, or a task), winning whole: with a [base], a
/// unit only one side changed takes that side's change; a unit both
/// changed, or any unit without a base, takes the newer edit. A unit on one
/// side only is kept: a deleted event stays as a marker, so a missing one
/// is never taken as deleted. Order: `main`'s units, then `other`'s new
/// ones; the calendar's own properties and layout are `main`'s, but for
/// its name, which merges as a unit does, `main`'s where both changed it
/// (an empty name lost is not told).
/// Time
/// zone blocks merge by zone like events (ours carry no stamp, so the
/// smaller text wins; both are right) and never count as lost. Never
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
          unit.key: _kept(
            mine,
            unit,
            bases?.unitOf(unit.key),
            (unit) => unit.text,
            tie: () => _newerOf(mine, unit),
          ),
    };
    final name = _kept(
      mains.name,
      others.name,
      bases?.name,
      (name) => name,
      tie: () => mains.name,
    );
    return MergedText(
      mains
          .withUnits([
            for (final unit in others.units) winners[unit.key] ?? unit,
          ])
          .named(name)
          .text,
      lost: [
        if (others.name.isNotEmpty &&
            _overwritten(others.name, name, bases?.name))
          'Calendar name',
        for (final unit in others.units)
          if (winners[unit.key] case final winner? when unit.key is! ZoneKey)
            for (final side in [mains.unitOf(unit.key)!, unit])
              if (_overwritten(
                side.text,
                winner.text,
                bases?.unitOf(unit.key)?.text,
              ))
                nameOfUnit(side),
      ],
    );
  }
}

/// The side a merge keeps of one thing (a unit, the name), of [a] and
/// [b] as [textOf] reads them: when one still is [base], the other one
/// (it holds the only change, stamped or not); else [tie].
T _kept<T>(
  T a,
  T b,
  T? base,
  String Function(T side) textOf, {
  required T Function() tie,
}) => switch (base == null ? null : textOf(base)) {
  final text? when textOf(a) == text => b,
  final text? when textOf(b) == text => a,
  _ => tie(),
};

/// Whether a merge that kept [kept] lost [side]: it differs, and it is a
/// change from [base] (or there is none).
bool _overwritten(String side, String kept, String? base) =>
    side != kept && side != base;

/// The newer of two versions [a] and [b] of one unit: by its latest
/// `LAST-MODIFIED` (none is oldest), then its highest `SEQUENCE`, then
/// its latest `DTSTAMP` (none is oldest; it orders only versions without
/// the first two, e.g. two exports, as an edit here always writes
/// `LAST-MODIFIED`), then the smaller text, so every device picks the
/// same.
CalendarUnit _newerOf(CalendarUnit a, CalendarUnit b) {
  final byStamp = _compare(_stampOf(a), _stampOf(b));
  if (byStamp != 0) return byStamp > 0 ? a : b;
  return a.text.compareTo(b.text) <= 0 ? a : b;
}

typedef _Stamp = ({DateTime? modified, int sequence, DateTime? stamped});

/// The latest edit stamp of any of [unit]'s components.
_Stamp _stampOf(CalendarUnit unit) => unit.components.fold(
  (modified: null, sequence: -1, stamped: null),
  (latest, component) {
    final sequence =
        int.tryParse(component.value('SEQUENCE')?.trim() ?? '') ?? -1;
    return (
      modified: _later(latest.modified, _timeIn(component, 'LAST-MODIFIED')),
      sequence: sequence > latest.sequence ? sequence : latest.sequence,
      stamped: _later(latest.stamped, _timeIn(component, 'DTSTAMP')),
    );
  },
);

/// The time [component]'s property [name] holds; `null` if none.
DateTime? _timeIn(Component component, String name) =>
    switch (component.property(name)) {
      final line? => timeOf(line)?.wall,
      null => null,
    };

/// The later of [a] and [b]; one if the other is `null`.
DateTime? _later(DateTime? a, DateTime? b) => switch ((a, b)) {
  (final a?, final b?) => a.isAfter(b) ? a : b,
  (final a, final b) => a ?? b,
};

/// Positive if [a] is newer than [b], negative if older, else 0.
int _compare(_Stamp a, _Stamp b) =>
    switch (_compareTimes(a.modified, b.modified)) {
      0 when a.sequence != b.sequence => a.sequence.compareTo(b.sequence),
      0 => _compareTimes(a.stamped, b.stamped),
      final byModified => byModified,
    };

/// [a] against [b], a missing one oldest.
int _compareTimes(DateTime? a, DateTime? b) => switch ((a, b)) {
  (final x?, final y?) => x.compareTo(y),
  (_?, null) => 1,
  (null, _?) => -1,
  (null, null) => 0,
};
