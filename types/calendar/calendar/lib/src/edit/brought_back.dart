import 'dart:math';

import '../model/calendar.dart';
import '../model/calendar_unit.dart';
import 'stamp.dart';

/// [back], the whole calendar a backup restore, or its undo or redo,
/// brings back over [now], as an edit at [at]: [back]'s layout, with each
/// unit as it comes back (see [_cameBack]) and those of [now] that stay:
/// its events as deleted markers, its time zone blocks.
Calendar broughtBack(Calendar back, Calendar now, DateTime at) =>
    back.withUnits([
      for (final unit in back.units) ?_cameBack(unit.key, unit, now, at),
      for (final unit in now.units)
        if (back.unitOf(unit.key) == null) ?_cameBack(unit.key, null, now, at),
    ]);

/// [now] with the units [back] holds by key (`null` for one the step
/// undone or redone added) as they come back as an edit at [at] (see
/// [_cameBack]).
Calendar unitsBroughtBack(
  Calendar now,
  Map<UnitKey, CalendarUnit?> back,
  DateTime at,
) => now.withUnits([
  for (final MapEntry(:key, :value) in back.entries)
    ?_cameBack(key, value, now, at),
]);

/// What unit [key] is once [back] (`null`: none) comes back over [now] as
/// an edit at [at], so a merge with [now]'s text, e.g. as another device
/// got it, keeps what came back: an event that differs from [now]'s
/// stamped anew, its `SEQUENCE` above both; an event [back] has not a
/// deleted marker; a time zone block [back] has not stays [now]'s (a
/// marker may still name its zone); any other unit as [back] has it.
/// `null` if the unit is none.
CalendarUnit? _cameBack(
  UnitKey key,
  CalendarUnit? back,
  Calendar now,
  DateTime at,
) {
  final current = now.unitOf(key);
  final event = switch (key) {
    UidKey(component: 'VEVENT', :final uid) => now.eventOf(uid),
    _ => null,
  };
  final isEvent = key is UidKey && key.component == 'VEVENT';
  return switch (back) {
    null when event != null => CalendarUnit.edited(key, [markerOf(event, at)]),
    null when key is ZoneKey => current,
    null => null,
    _ when !isEvent || back.text == current?.text => back,
    _ => CalendarUnit.edited(key, [
      for (final component in back.components)
        stamped(component, at, above: _latestSequence(current)),
    ]),
  };
}

/// The highest `SEQUENCE` of [unit]'s components; -1 if none has one.
int _latestSequence(CalendarUnit? unit) =>
    unit?.components.map(sequenceOf).fold<int>(-1, max) ?? -1;
