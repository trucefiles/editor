import '../model/calendar.dart';
import '../model/calendar_unit.dart';
import 'stamp.dart';

/// [back], the whole calendar a backup restore, or its undo or redo,
/// brings back over [now], as an edit at [at]: [back]'s layout, with each
/// unit as it comes back (see [_cameBack]) and those of [now] that stay:
/// its events as deleted markers, its time zone blocks still named.
/// [filed] is the calendar as the file owner has it (`null`: none).
Calendar broughtBack(
  Calendar back,
  Calendar now,
  DateTime at, {
  required Calendar? filed,
}) {
  final lacking = [
    for (final unit in now.units)
      if (back.unitOf(unit.key) == null) unit.key,
  ];
  return _unusedZonesGone(
    back.withUnits([
      for (final unit in back.units) ?_cameBack(unit.key, unit, now, at, filed),
      for (final key in lacking) ?_cameBack(key, null, now, at, filed),
    ]),
    lacking,
  );
}

/// [now] with the units [back] holds by key (`null` for one the step
/// undone or redone added) as they come back as an edit at [at] (see
/// [_cameBack]; [filed] as [broughtBack] says).
Calendar unitsBroughtBack(
  Calendar now,
  Map<UnitKey, CalendarUnit?> back,
  DateTime at, {
  required Calendar? filed,
}) => _unusedZonesGone(
  now.withUnitsChanged({
    for (final MapEntry(:key, :value) in back.entries)
      key: _cameBack(key, value, now, at, filed),
  }),
  [
    for (final MapEntry(:key, :value) in back.entries)
      if (value == null) key,
  ],
);

/// [calendar] without the time zone blocks among [lacking] (keys the side
/// brought back has no unit of) that none of its units names any more:
/// nothing reads times by them. Asks for the zones named only when a
/// block may go.
Calendar _unusedZonesGone(Calendar calendar, List<UnitKey> lacking) =>
    calendar.withUnitsChanged({
      for (final key in lacking)
        if (key case ZoneKey(:final zone)
            when !calendar.zonesNamed.contains(zone))
          key: null,
    });

/// What unit [key] is once [back] (`null`: none) comes back over [now] as
/// an edit at [at], so a merge with [now]'s text, e.g. as another device
/// got it, keeps what came back: an event that differs from [now]'s
/// stamped anew, its `SEQUENCE` above both; an event [back] has not a
/// deleted marker, or none at all where [filed] (the calendar as the
/// file owner has it) has no unit of it: no file can hold it then, so no
/// merge needs the marker; a time zone block [back] has not stays
/// [now]'s here, as a marker may name its zone (it goes later only if
/// nothing names it, see [_unusedZonesGone]); any other unit as [back]
/// has it.
/// `null` if the unit is none.
CalendarUnit? _cameBack(
  UnitKey key,
  CalendarUnit? back,
  Calendar now,
  DateTime at,
  Calendar? filed,
) {
  final current = now.unitOf(key);
  final (isEvent, event) = switch (key) {
    UidKey(component: 'VEVENT', :final uid) => (true, now.eventOf(uid)),
    _ => (false, null),
  };
  return switch (back) {
    null when event != null && filed?.unitOf(key) != null =>
      CalendarUnit.edited(key, [markerOf(event, at)]),
    null when key is ZoneKey => current,
    null => null,
    _ when !isEvent || back.text == current?.text => back,
    _ => stampedOver(back, at, current),
  };
}
