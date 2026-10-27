import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/setting_store.dart';

export '../storage/setting_store.dart';

/// One setting of this device, loaded from its store: each change starts
/// from the value the change before left, shows at once, and is saved.
abstract class SettingController<T> extends AsyncNotifier<T> {
  /// The setting's store.
  Provider<SettingStore<T>> get store;

  /// What [value] counts as here; the value itself unless a setting says
  /// otherwise (e.g. a choice this platform can't do).
  T fit(T value) => value;

  @override
  Future<T> build() async => fit(await ref.watch(store).load());

  /// Sets the value to [value] (see [change]).
  Future<void> set(T value) => change((_) => value);

  /// Changes the value with [change], once it is loaded. Shows the new
  /// value at once and saves it; nothing if it stays the same.
  Future<void> change(T Function(T value) change) async {
    // While it (re)loads, an old value may still show.
    if (state.isLoading || !state.hasValue) await future;
    final before = state.requireValue;
    final after = fit(change(before));
    if (const DeepCollectionEquality().equals(before, after)) return;
    state = AsyncData(after);
    await ref.read(store).save(after);
  }
}
