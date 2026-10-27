import '../common/moment.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../versions/resolve_error.dart';

/// The keep under way, answered at [ticket]; once it ended ([endedAt]),
/// its [error] if it failed.
typedef KeepUnderWay = ({
  Ticket ticket,
  EffectId id,
  Moment? endedAt,
  ResolveError? error,
});

/// The compare owner's bookkeeping behind its state.
final class CompareWork {
  const CompareWork({this.loading, this.keep, this.nextId = 0});

  /// The load waited for; `null` while none is.
  final EffectId? loading;

  /// `null` while no keep is under way.
  final KeepUnderWay? keep;

  final int nextId;

  CompareWork copyWith({
    Object? loading = _same,
    Object? keep = _same,
    int? nextId,
  }) => CompareWork(
    loading: identical(loading, _same) ? this.loading : loading as EffectId?,
    keep: identical(keep, _same) ? this.keep : keep as KeepUnderWay?,
    nextId: nextId ?? this.nextId,
  );
}

/// Marks a [CompareWork.copyWith] field left as it is.
const _same = Object();
