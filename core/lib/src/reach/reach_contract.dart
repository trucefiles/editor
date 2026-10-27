/// The folder reach owner's contract: what reaches it, what it decides,
/// what it leads to. One per added folder; it tells whether the folder's
/// files can be reached, from how accesses to them go.
library;

import '../owners/ask.dart';
import '../owners/effects.dart';

/// Whether a folder's files can be reached.
enum Reach {
  reachable,

  /// An access failed and the folder could not be read: checking again for
  /// a short while. Nothing that depends on the folder should run.
  retrying,

  /// The folder could not be read for a while. Any access that works makes
  /// it [reachable] again.
  unreachable,
}

/// How an access to the folder's files went.
enum Access {
  worked,

  /// Failed in a way that may mean the folder is out of reach (not found,
  /// no access, I/O failure).
  mayBeGone,

  /// Failed in a way that says nothing about reach (e.g. the file changed).
  otherError,
}

/// What the reach owner handles: inputs anyone may send, and the results
/// of its effects.
sealed class ReachMessage {
  const ReachMessage();
}

// Inputs.

sealed class ReachInput extends ReachMessage {
  const ReachInput();
}

/// An access to the folder's files ended as [access].
final class Accessed extends ReachInput {
  const Accessed(this.access);

  final Access access;
}

/// Tell the reach once no check or retry is under way, e.g. to tell
/// whether a failed save failed because the folder is out of reach;
/// answered by [Settled].
final class Settle extends ReachInput implements Asking {
  const Settle(this.ticket);

  @override
  final Ticket ticket;
}

// Results.

sealed class ReachResult extends ReachMessage {
  const ReachResult();
}

/// Whether [CheckFolder] could list the folder.
final class FolderChecked extends ReachResult {
  const FolderChecked(this.id, {required this.ok});

  final EffectId id;
  final bool ok;
}

/// The wait [WaitToRetry] started is over.
final class RetryWaited extends ReachResult {
  const RetryWaited(this.id);

  final EffectId id;
}

// Events.

sealed class ReachEvent {
  const ReachEvent();
}

/// The answer to [Settle]: the reach once no check runs.
final class Settled extends ReachEvent implements Answering {
  const Settled(this.ticket, this.reach);

  @override
  final Ticket ticket;
  final Reach reach;
}

// Effects.

sealed class ReachEffect {
  const ReachEffect();
}

/// List the folder itself, without its contents; a check that takes too
/// long counts as failed. Answered by [FolderChecked].
final class CheckFolder extends ReachEffect {
  const CheckFolder(this.id);

  final EffectId id;
}

/// Wait [delay] before the next check; then [RetryWaited].
final class WaitToRetry extends ReachEffect implements Wait<RetryWaited> {
  const WaitToRetry(this.id, this.delay);

  @override
  final EffectId id;
  @override
  final Duration delay;

  @override
  RetryWaited get done => RetryWaited(id);
}
