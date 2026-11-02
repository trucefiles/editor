import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A remembered pick, for this app run only; `null`: nothing picked.
class Choice<T> extends Notifier<T?> {
  @override
  T? build() => null;

  void choose(T? value) => state = value;
}
