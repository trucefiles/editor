import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// A number setting; odd numbers count as the even one below.
final class _Even extends SettingController<int> {
  @override
  Provider<SettingStore<int>> get store => _storeProvider;

  @override
  int fit(int value) => value - value % 2;
}

final _evenProvider = AsyncNotifierProvider<_Even, int>(_Even.new);

void main() {
  late ProviderContainer container;
  late _Store store;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    store = container.read(_storeProvider) as _Store;
    container.listen(_evenProvider, (_, _) {});
  });

  _Even setting() => container.read(_evenProvider.notifier);

  int? shown() => container.read(_evenProvider).value;

  test('shows a new value at once, then saves it', () async {
    store.loading.complete(0);
    await container.read(_evenProvider.future);

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
    await container.read(_evenProvider.future);

    await Future.wait([
      setting().change((value) => value + 2),
      setting().change((value) => value + 2),
    ]);

    expect(store.saves, [2, 4]);
  });

  test('fits what it loads and what it is set to', () async {
    store.loading.complete(3);
    expect(await container.read(_evenProvider.future), 2);

    await setting().set(7);
    expect(shown(), 6);
  });

  test('the same value again saves nothing', () async {
    store.loading.complete(2);
    await container.read(_evenProvider.future);

    await setting().set(3);

    expect(store.saves, isEmpty);
  });
}
