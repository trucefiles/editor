import 'dart:ui' show AppExitResponse;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/alerts/alerts_wiring.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/app_end/app_end_source.dart';
import 'package:truce_editor/app_end/app_end_wiring.dart';
import 'package:truce_editor/calendar_tab/calendar_clock.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../alerts/quiet_alerts.dart';
import '../support.dart';

/// A store in memory.
final class _Store implements SettingStore<RingState> {
  RingState kept = RingState.none;

  @override
  Future<RingState> load() async => kept;

  @override
  Future<void> save(RingState value) async => kept = value;
}

void main() {
  final start = DateTime(2026, 11, 18, 9);
  late DateTime now;
  late _Store store;

  Future<ProviderContainer> showApp(WidgetTester tester) async {
    now = start;
    store = _Store();
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
            loadedDeviceSettingsProvider.overrideWithValue(
              DeviceSettings.standard,
            ),
            deviceIdProvider.overrideWithValue('0123456789abcdef'),
            systemTrayProvider.overrideWithValue(null),
            appEndSourcesProvider.overrideWithValue(const []),
            calendarNowProvider.overrideWithValue(() => now),
            ringStateStoreProvider.overrideWithValue(store),
            ...quietAlerts(),
          ],
          child: const TruceApp(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(TruceApp)));
  }

  testWidgets("at the user's quit, the alerts' stop is kept first", (
    tester,
  ) async {
    await showApp(tester);
    now = start.add(const Duration(hours: 2));

    final answer = await tester.runAsync(
      () => tester.binding.handleRequestAppExit(),
    );

    expect(answer, AppExitResponse.exit);
    expect(store.kept.lastAlive, now);
  });

  testWidgets("ended from outside, the alerts' stop is kept with the files'", (
    tester,
  ) async {
    final container = await showApp(tester);
    now = start.add(const Duration(hours: 3));

    await tester.runAsync(
      () => container.read(appEndProvider).ended(AppEndKind.sessionEnding),
    );

    expect(store.kept.lastAlive, now);
  });
}
