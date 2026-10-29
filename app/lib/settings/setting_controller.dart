import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

/// One setting of this device, kept in its store: each change starts from
/// the value the change before left, shows at once, and is saved.
abstract class SettingController<T> extends AsyncNotifier<T> {
  /// The setting's store.
  Provider<SettingStore<T>> get store;

  /// The value it starts from: what [store] holds, unless the setting was
  /// loaded already (then it shows at once, never "still loading").
  FutureOr<T> initial() => ref.watch(store).load();

  @override
  FutureOr<T> build() => initial();

  /// Sets the value to [value] (see [change]).
  Future<void> set(T value) => change((_) => value);

  /// Changes the value with [change], once it is loaded. Shows the new
  /// value at once and saves it; nothing if it stays the same.
  Future<void> change(T Function(T value) change) async {
    // While it (re)loads, an old value may still show.
    if (state.isLoading || !state.hasValue) await future;
    final before = state.requireValue;
    final after = change(before);
    if (const DeepCollectionEquality().equals(before, after)) return;
    state = AsyncData(after);
    await ref.read(store).save(after);
  }
}
