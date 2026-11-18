import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';

import '../calendar_tab/calendar_clock.dart';
import '../calendar_tab/calendar_tab_controller.dart';
import '../folder_state/folder_state_controller.dart';
import '../platform/app_activity.dart';
import '../platform/platform_wiring.dart';
import '../settings/device_settings_controller.dart';
import '../storage/app_storage.dart';
import 'app_alerts.dart';
import 'ring_state_store.dart';

/// Where the alert planner keeps its state.
final ringStateStoreProvider = Provider<SettingStore<RingState>>(
  (ref) => RingStateStore.of(ref.watch(appStorageProvider)),
);

/// The app's alert planner, for the app's whole run.
final alertPlannerProvider = Provider<AlertPlanner>((ref) {
  final planner = AlertPlanner(
    ringer: ref.watch(ringerProvider),
    store: ref.watch(ringStateStoreProvider),
  );
  ref.onDispose(() => unawaited(planner.close()));
  return planner;
});

/// The app's alerts, from its start on, fed the calendars shown in the
/// Calendar tab and the alert style; they stop as the app's engine
/// detaches (Android may end it with the process still running, and the
/// background check mustn't wait). The app's end keeps their stop before
/// quitting (`appEndProvider`). Also schedules the background check where
/// there is one.
final alertsProvider = Provider<AppAlerts>((ref) {
  final alerts = AppAlerts(
    planner: ref.watch(alertPlannerProvider),
    clock: ref.watch(calendarClockProvider),
    role: ref.watch(plannerRoleProvider),
    listFolders: () =>
        unawaited(ref.read(folderContentsProvider.notifier).refresh()),
  );
  ref.listen(calendarTabProvider, (_, tab) {
    if (tab.value case final tab?) alerts.show(shownOf(tab));
  }, fireImmediately: true);
  ref.listen(
    deviceSettingsProvider.select((s) => s.value?.alertStyle),
    (_, _) => alerts.handAgain(),
  );
  final detach = AppLifecycleListener(onDetach: () => unawaited(alerts.stop()));
  ref.onDispose(() {
    detach.dispose();
    alerts.dispose();
  });
  unawaited(alerts.start());
  if (ref.read(alertCheckScheduleProvider) case final schedule?) {
    unawaited(schedule());
  }
  return alerts;
});

/// The calendars of [tab] the alerts plan from: the shown ones, as read
/// (one that can't be read keeps what was planned from it).
ShownCalendars shownOf(TabCalendars tab) => (
  calendars: {
    for (final calendar in tab.offered)
      if (calendar case ShownCalendar(:final file, :final calendar))
        file.key: listedCalendar(file, calendar)
      else if (calendar case UnreadableCalendar(:final file))
        file.key: listedCalendar(file, null),
  },
  sees: tab.sees,
);

/// Asks the user once a run to let alerts show, the first time a shown
/// calendar has an alert to ring while they may not.
final alertPermissionAskProvider = Provider<void>((ref) {
  final permissions = ref.watch(alertPermissionsProvider);
  late final StreamSubscription<PlannerState> changes;
  changes = ref.watch(alertPlannerProvider).changes.listen((state) async {
    if (state.planned.isEmpty) return;
    await changes.cancel();
    if (!await permissions.mayNotify()) await permissions.askToNotify();
  });
  ref.onDispose(() => unawaited(changes.cancel()));
});

/// How often the folders are listed for alerts while the app isn't in
/// use (hidden, in the tray or in the background), as screens then don't
/// follow the folders: calendars changed elsewhere reach the alerts
/// within this.
const quietListingEvery = Duration(minutes: 15);

/// Lists the folders every [quietListingEvery] while the app isn't in
/// use, so the alerts hear of calendars changed elsewhere.
final quietListingProvider = Provider<void>((ref) {
  final timer = Timer.periodic(quietListingEvery, (_) {
    if (!ref.read(appActiveProvider)) {
      unawaited(ref.read(folderContentsProvider.notifier).refresh());
    }
  });
  ref.onDispose(timer.cancel);
});
