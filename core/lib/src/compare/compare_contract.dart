/// The compare owner's contract: what reaches it, what it decides, what it
/// leads to. One per compare screen; it shows one comparison of two
/// versions of a file (its [Sides]) and carries out the user's keep, then
/// goes on to the next [Target] a later scan finds, if any. Generic: a
/// target may be a sync conflict or a backup.
library;

import '../common/moment.dart';
import '../common/result.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../storage/file_store.dart';
import '../versions/resolution.dart';
import '../versions/resolve_error.dart';

/// What the compare owner handles: inputs anyone may send, and the
/// results of its effects.
sealed class CompareMessage<Target, Sides> {
  const CompareMessage();
}

// Inputs.

sealed class CompareInput<Target, Sides> extends CompareMessage<Target, Sides> {
  const CompareInput();
}

/// Keep one side of what shows; answered by [KeepAnswer] once a scan
/// after the keep told what comes next. Taken only while sides show.
final class Keep<Target, Sides> extends CompareInput<Target, Sides>
    implements Asking {
  const Keep(this.ticket, this.choice);

  @override
  final Ticket ticket;
  final Resolution choice;
}

/// A scan that started at [startedAt] found [next] to compare (e.g. the
/// document's oldest conflict copy left), or nothing.
final class ScanSeen<Target, Sides> extends CompareInput<Target, Sides> {
  const ScanSeen(this.next, {required this.startedAt});

  final Target? next;
  final Moment startedAt;
}

// Results.

sealed class CompareResult<Target, Sides>
    extends CompareMessage<Target, Sides> {
  const CompareResult();
}

/// How [LoadSides] went.
final class SidesLoaded<Target, Sides> extends CompareResult<Target, Sides> {
  const SidesLoaded(this.id, this.sides);

  final EffectId id;
  final Result<Sides, StoreError> sides;
}

/// How [KeepChoice] went; it ended at [endedAt].
final class KeepEnded<Target, Sides> extends CompareResult<Target, Sides> {
  const KeepEnded(this.id, this.outcome, {required this.endedAt});

  final EffectId id;
  final Result<void, ResolveError> outcome;
  final Moment endedAt;
}

// Events.

/// The answer to [Keep]: whether it was [taken] (sides showed, no keep
/// was under way), why it failed if it did, and whether nothing is left
/// to compare.
final class KeepAnswer implements Answering {
  const KeepAnswer(
    this.ticket, {
    required this.taken,
    this.error,
    this.done = false,
  });

  @override
  final Ticket ticket;
  final bool taken;
  final ResolveError? error;
  final bool done;
}

// Effects.

sealed class CompareEffect<Target, Sides> {
  const CompareEffect();
}

/// Load the sides of [target]; answered by [SidesLoaded].
final class LoadSides<Target, Sides> extends CompareEffect<Target, Sides> {
  const LoadSides(this.id, this.target);

  final EffectId id;
  final Target target;
}

/// Keep [choice] of [sides] of [target], only over the versions shown;
/// answered by [KeepEnded].
final class KeepChoice<Target, Sides> extends CompareEffect<Target, Sides> {
  const KeepChoice(this.id, this.target, this.sides, this.choice);

  final EffectId id;
  final Target target;
  final Sides sides;
  final Resolution choice;
}

/// Scan the folders, so the screens and the next [ScanSeen] show the keep.
/// No result.
final class RescanAfterKeep<Target, Sides>
    extends CompareEffect<Target, Sides> {
  const RescanAfterKeep();
}

// State.

/// What the compare screen shows.
sealed class CompareState<Target, Sides> {
  const CompareState();

  /// What is compared, or was last.
  Target get target;
}

/// The sides of [target] load.
final class CompareLoading<Target, Sides> extends CompareState<Target, Sides> {
  const CompareLoading(this.target);

  @override
  final Target target;
}

/// The [sides] of [target] show; the user may keep one.
final class CompareShowing<Target, Sides> extends CompareState<Target, Sides> {
  const CompareShowing(this.target, this.sides);

  @override
  final Target target;
  final Sides sides;
}

/// The sides of [target] could not be loaded ([error]); loaded again
/// with the next scan.
final class CompareLoadFailed<Target, Sides>
    extends CompareState<Target, Sides> {
  const CompareLoadFailed(this.target, this.error);

  @override
  final Target target;
  final StoreError error;
}

/// A keep of [sides] of [target] is under way, until a scan after it
/// tells what comes next.
final class CompareKeeping<Target, Sides> extends CompareState<Target, Sides> {
  const CompareKeeping(this.target, this.sides);

  @override
  final Target target;
  final Sides sides;
}

/// Nothing is left to compare; the [sides] of [target] kept last still
/// show while the screen closes.
final class CompareDone<Target, Sides> extends CompareState<Target, Sides> {
  const CompareDone(this.target, this.sides);

  @override
  final Target target;
  final Sides sides;
}
