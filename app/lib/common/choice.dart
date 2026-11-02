import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A remembered pick, for this app run only; `null`: nothing picked.
class Choice<T> extends Notifier<T?> {
  @override
  T? build() => null;

  void choose(T? value) => state = value;

  /// Drops the pick if it is another value than [value], so a filter by
  /// this choice shows what [value] picks.
  void reveal(T value) {
    if (state != null && state != value) state = null;
  }
}
