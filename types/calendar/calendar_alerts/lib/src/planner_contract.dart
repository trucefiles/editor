import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'planned_alert.dart';
import 'ring_state.dart';

/// How far ahead alerts are handed to the ringer.
const planAhead = Duration(days: 7);

/// At most this many alerts are handed to the ringer at once, the
/// nearest first (Android holds at most 500 scheduled alarms per app).
const mostPlanned = 300;

/// What reaches the planner, from any source; each is answered by a
/// [Handled] with its [ticket] once its outcome is rung and kept.
sealed class PlannerInput implements Asking {
  PlannerInput({Ticket? ticket}) : ticket = ticket ?? Ticket();

  @override
  final Ticket ticket;
}

/// The app or the background check started at [now]: alerts from the last time something could ring them
/// until [now] are told as missed as their calendars are listed.
final class Started extends PlannerInput {
  Started({required this.now, super.ticket});

  final DateTime now;
}

/// The calendars shown on this device at [now], in [zone], all of them:
/// any planned from that isn't here any more is silenced, unless the
/// listing couldn't see where it is ([sees]). Each holds its calendar
/// where it was read; one not read must be one the plan doesn't need to
/// read anew ([RingState.needsRead]). One that needed reading but came
/// without is read at a later listing.
final class CalendarsListed extends PlannerInput {
  CalendarsListed({
    required this.now,
    required this.zone,
    required this.calendars,
    required this.sees,
    super.ticket,
  });

  final DateTime now;
  final String zone;
  final Map<FileKey, ListedCalendar> calendars;

  /// Whether the listing would show [file] were it there: not where a
  /// folder or subfolder couldn't be read. A calendar it doesn't see keeps
  /// what was planned from it.
  final bool Function(FileKey file) sees;
}

/// A calendar as listed: its [version] (the file's version as text, the
/// same for the same version across runs), and its [calendar] if it was
/// read.
typedef ListedCalendar = ({String version, Calendar? calendar});

/// The app's own clock rang an alert at [now]: alerts until then weren't
/// missed.
final class Rang extends PlannerInput {
  Rang({required this.now, super.ticket});

  final DateTime now;
}

/// The app or the background check stops at [now]: alerts until then
/// weren't missed.
final class Stopping extends PlannerInput {
  Stopping({required this.now, super.ticket});

  final DateTime now;
}

/// Hands every planned alert still to come after [now] to the ringer
/// again, each under its own number, in place of itself (e.g. as the way
/// alerts ring changed).
final class HandAgain extends PlannerInput {
  HandAgain({required this.now, super.ticket});

  final DateTime now;
}

/// What the planner holds: its [ring] state as kept; when this run
/// started ([startedAt], `null`: not yet); since when alerts count as
/// missed in it ([missedSince], `null`: none), with the calendars already
/// checked for them; the calendars planned from when the run started
/// ([plannedAtStart]); and whether the run [listed] calendars yet.
final class PlannerState {
  const PlannerState({
    required this.ring,
    this.startedAt,
    this.missedSince,
    this.missedChecked = const {},
    this.plannedAtStart = const {},
    this.listed = false,
  });

  final RingState ring;
  final DateTime? startedAt;
  final DateTime? missedSince;
  final Set<FileKey> missedChecked;
  final Set<FileKey> plannedAtStart;
  final bool listed;

  /// This state with [ring] instead, the same run.
  PlannerState withRing(RingState ring) => PlannerState(
    ring: ring,
    startedAt: startedAt,
    missedSince: missedSince,
    missedChecked: missedChecked,
    plannedAtStart: plannedAtStart,
    listed: listed,
  );

  /// Whether [file] was shown when the run started, and not yet listed
  /// in it: shown in the run's first listing, or planned from before the
  /// run (e.g. in a folder listed later). Its alerts from the run's start
  /// on ring, and those before count as missed; a calendar shown only
  /// later (turned on, new, moved) rings from then on.
  bool fromStart(FileKey file) =>
      startedAt != null &&
      !missedChecked.contains(file) &&
      (!listed || plannedAtStart.contains(file));

  /// The alerts planned now.
  Iterable<PlannedAlert> get planned =>
      ring.handed.values.map((handed) => handed.alert);
}

/// Tells that the input with [ticket] was handled.
final class Handled implements Answering {
  const Handled(this.ticket);

  @override
  final Ticket ticket;
}
