import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/settings/setting_controller.dart';

/// A store in memory whose load ends when a test says.
final class _Store implements SettingStore<int> {
  final loading = Completer<int>();
  final saves = <int>[];

  @override
  Future<int> load() => loading.future;

  @override
  Future<void> save(int value) async => saves.add(value);
}

final _storeProvider = Provider<SettingStore<int>>((_) => _Store());

/// A number setting.
final class _Number extends SettingController<int> {
  @override
  Provider<SettingStore<int>> get store => _storeProvider;
}

final _numberProvider = AsyncNotifierProvider<_Number, int>(_Number.new);

/// A number setting that starts from a value loaded already.
final class _Loaded extends _Number {
  @override
  int initial() => 5;
}

final _loadedProvider = AsyncNotifierProvider<_Number, int>(_Loaded.new);

void main() {
  late ProviderContainer container;
  late _Store store;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    store = container.read(_storeProvider) as _Store;
    container.listen(_numberProvider, (_, _) {});
  });

  _Number setting() => container.read(_numberProvider.notifier);

  int? shown() => container.read(_numberProvider).value;

  test('shows a new value at once, then saves it', () async {
    store.loading.complete(0);
    await container.read(_numberProvider.future);

    final saving = setting().set(4);
    expect(shown(), 4);
    await saving;
    expect(store.saves, [4]);
  });

  test('a change while it loads starts from the loaded value', () async {
    final changing = setting().change((value) => value + 2);
    store.loading.complete(6);
    await changing;

    expect(shown(), 8);
    expect(store.saves, [8]);
  });

  test('each change starts from the one before', () async {
    store.loading.complete(0);
    await container.read(_numberProvider.future);

    await Future.wait([
      setting().change((value) => value + 2),
      setting().change((value) => value + 2),
    ]);

    expect(store.saves, [2, 4]);
  });

  test('a value loaded already shows at once, and changes are saved', () async {
    expect(container.read(_loadedProvider).value, 5);

    await container.read(_loadedProvider.notifier).change((value) => value + 1);

    expect(container.read(_loadedProvider).value, 6);
    expect(store.saves, [6]);
  });

  test('the same value again saves nothing', () async {
    store.loading.complete(2);
    await container.read(_numberProvider.future);

    await setting().set(2);

    expect(store.saves, isEmpty);
  });
}
