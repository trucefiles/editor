import '../owners/ask.dart';
import '../owners/effects.dart';

/// The check cycle under way, if any.
sealed class Checking {
  const Checking(this.id);

  /// The id of the effect under way.
  final EffectId id;
}

/// The first check after a failed access; [worked]: an access worked
/// since it began, so the folder is there whatever it finds.
final class FirstCheck extends Checking {
  const FirstCheck(super.id, {this.worked = false});

  final bool worked;
}

/// Waiting before the next check, [left] checks to go.
final class RetryWait extends Checking {
  const RetryWait(super.id, {required this.left});

  final int left;
}

/// A check after a wait, [left] checks to go with this one.
final class RetryCheck extends Checking {
  const RetryCheck(super.id, {required this.left});

  final int left;
}

/// The reach owner's bookkeeping behind its state.
final class ReachWork {
  const ReachWork({this.checking, this.settles = const [], this.nextId = 0});

  /// `null` while no check or wait is under way.
  final Checking? checking;

  /// The [Settle]s waiting for no check to be under way.
  final List<Ticket> settles;

  final int nextId;
}
