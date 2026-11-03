import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The values picked in a filter, for this app run only; none picked
/// means the filter lets everything through.
class Picks<T> extends Notifier<Set<T>> {
  @override
  Set<T> build() => const {};

  /// Picks [value], or unpicks it if it is picked.
  void toggle(T value) => state = state.contains(value)
      ? state.difference({value})
      : {...state, value};

  /// Unpicks [value], e.g. as it no longer exists.
  void drop(T value) => state = state.difference({value});

  /// Picks [value] too while others are picked, so a filter by these
  /// picks lets [value] through; nothing picked already does.
  void reveal(T value) {
    if (state.isNotEmpty && !state.contains(value)) state = {...state, value};
  }
}
