import 'package:collection/collection.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

import 'planned_alert.dart';
import 'planner_contract.dart';
import 'ring_state.dart';
import 'ringer.dart';

/// One step of the planner: its next [state], what the ringer is told,
/// and the alerts [missed].
typedef PlanStep = ({
  PlannerState state,
  List<RingChange> changes,
  List<PlannedAlert> missed,
});

/// What [input] makes of [state], for a ringer that rings on its own
/// while the app isn't running if [ringsWhileClosed]. Pure.
PlanStep planStep(
  PlannerState state,
  PlannerInput input, {
  required bool ringsWhileClosed,
}) => switch (input) {
  Started(:final now) => _quiet(
    PlannerState(
      ring: ringsWhileClosed
          ? state.ring
          // Nothing the ringer held is held any more; each calendar is
          // read anew as the run first lists it.
          : state.ring.copyWith(handed: const {}),
      startedAt: now,
      missedSince: state.ring.lastAlive,
      plannedAtStart: state.ring.versions.keys.toSet(),
    ),
  ),
  final CalendarsListed listing => _listed(
    state,
    listing,
    ringsWhileClosed: ringsWhileClosed,
  ),
  Rang(:final now) || Stopping(:final now) => _quiet(
    state.withRing(state.ring.copyWith(lastAlive: _later(state.ring, now))),
  ),
  HandAgain(:final now) => (
    state: state,
    changes: [
      for (final (:number, :alert) in state.ring.handed.values)
        if (alert.at.isAfter(now)) Ring(number, alert),
    ],
    missed: const [],
  ),
};

/// The later of [ring]'s last alive and [time].
DateTime _later(RingState ring, DateTime time) => switch (ring.lastAlive) {
  final last? when last.isAfter(time) => last,
  _ => time,
};

PlanStep _quiet(PlannerState state) =>
    (state: state, changes: const [], missed: const []);

/// Plans the calendars of [listing]: those read anew give their alerts of
/// the next days ([planAhead]); the others keep theirs, as do those the
/// listing couldn't see; the nearest [mostPlanned] are handed to the
/// ringer. A calendar shown since the run's start
/// ([PlannerState.fromStart]) hands its alerts from the run's start on,
/// and tells its alerts missed from [PlannerState.missedSince] until the
/// run started, one per item: the latest.
PlanStep _listed(
  PlannerState state,
  CalendarsListed listing, {
  required bool ringsWhileClosed,
}) {
  final CalendarsListed(:now, :zone, :calendars, :sees) = listing;
  final ring = state.ring;
  // Planned from, not listed, but maybe still there.
  bool kept(FileKey file) => !calendars.containsKey(file) && !sees(file);
  // On a ringer that forgot all at the start, a calendar not yet read in
  // the run holds nothing.
  bool forgotten(FileKey file) =>
      !ringsWhileClosed && !state.missedChecked.contains(file);
  final read = {
    for (final MapEntry(key: file, value: (:version, :calendar))
        in calendars.entries)
      if (calendar != null &&
          (ring.needsRead(file, version, now: now, zone: zone) ||
              forgotten(file)))
        file: calendar,
  };
  // A plan that moves on to new days covers them only for the calendars
  // it read: any other keeps no version, so it is read at the next
  // listing.
  final movesOn = ring.movesOn(now: now, zone: zone);
  String? keptVersion(FileKey file) => movesOn ? null : ring.versions[file];
  final until = now.add(planAhead);
  // From when a calendar's alerts are handed: from the run's start for one
  // shown since then (what came meanwhile rings at once), else from now.
  DateTime handedFrom(FileKey file) => switch (state.startedAt) {
    final started? when state.fromStart(file) => started,
    _ => now,
  };
  final chosen = [
    for (final (number: _, :alert) in ring.handed.values)
      if ((calendars.containsKey(alert.file) || kept(alert.file)) &&
          !read.containsKey(alert.file) &&
          alert.at.isAfter(now))
        alert,
    for (final MapEntry(key: file, value: calendar) in read.entries)
      for (final alert in alertsIn(calendar, handedFrom(file), until))
        if (alert.at.isAfter(handedFrom(file))) PlannedAlert.of(file, alert),
  ].sortedBy((alert) => alert.at).take(mostPlanned).toList();
  final added = [
    for (final alert in chosen)
      if (ring.handed[alert.id]?.alert != alert) alert,
  ];
  final newOnes = added.where((alert) => !ring.handed.containsKey(alert.id));
  final numbers = {
    for (final (index, alert) in newOnes.indexed)
      alert.id: ring.nextNumber + index,
  };
  final handed = {
    for (final alert in chosen)
      alert.id: (
        number: ring.handed[alert.id]?.number ?? numbers[alert.id]!,
        alert: alert,
      ),
  };
  final checked = {
    for (final MapEntry(key: file, value: (version: _, :calendar))
        in calendars.entries)
      file: ?calendar,
  };
  final since = state.missedSince;
  return (
    state: PlannerState(
      ring: ring.copyWith(
        handed: handed,
        nextNumber: ring.nextNumber + numbers.length,
        versions: {
          for (final MapEntry(key: file, value: version)
              in ring.versions.entries)
            if (kept(file) && !movesOn) file: version,
          for (final MapEntry(key: file, value: (:version, calendar: _))
              in calendars.entries)
            file: ?(read.containsKey(file) ? version : keptVersion(file)),
        },
        plannedOn: dayOf(now),
        zone: zone,
        // The run's missed alerts are told; on a ringer that rings on its
        // own, everything due until now was handed to it.
        lastAlive: switch (state.startedAt) {
          final started? => _later(ring, ringsWhileClosed ? now : started),
          null => null,
        },
      ),
      startedAt: state.startedAt,
      missedSince: since,
      missedChecked: {...state.missedChecked, ...checked.keys},
      plannedAtStart: state.plannedAtStart,
      listed: true,
    ),
    changes: [
      for (final alert in added) Ring(handed[alert.id]!.number, alert),
      for (final (:number, :alert) in ring.handed.values)
        if (!handed.containsKey(alert.id) && alert.at.isAfter(now))
          Silence(number),
    ],
    missed: switch ((since, state.startedAt)) {
      (final since?, final started?) => _latestPerItem([
        for (final MapEntry(key: file, value: calendar) in checked.entries)
          if (state.fromStart(file))
            for (final alert in _between(calendar, since, started))
              if (PlannedAlert.of(file, alert) case final missed
                  when missed.relevantAt(now) &&
                      !(ringsWhileClosed && ring.handed.containsKey(missed.id)))
                missed,
      ]),
      _ => const [],
    },
  );
}

/// The latest of [alerts] of each item, in time order: a repeating task
/// missed daily tells once.
List<PlannedAlert> _latestPerItem(List<PlannedAlert> alerts) => [
  ...{
    for (final alert in alerts.sortedBy((alert) => alert.at))
      (alert.file, alert.uid): alert,
  }.values,
].sortedBy((alert) => alert.at);

/// The alerts of [calendar] after [since], up to and with [until].
List<Alert> _between(Calendar calendar, DateTime since, DateTime until) {
  const tick = Duration(microseconds: 1);
  return alertsIn(calendar, since.add(tick), until.add(tick));
}
