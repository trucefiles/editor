import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../alerts/alert_check_wiring.dart';
import '../../storage/app_start.dart';

const _check = 'io.github.trucefiles.editor.alert_check';

/// Asks the system to run the alerts' background check ([alertCheckOf])
/// about every 6 hours, with the app closed too (the system batches it
/// with other work); kept as it is if already asked.
Future<void> scheduleAlertCheck() async {
  await Workmanager().initialize(runAlertCheck);
  await Workmanager().registerPeriodicTask(
    _check,
    _check,
    frequency: const Duration(hours: 6),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Where the system starts the background check, on an isolate of its
/// own with the app's wiring and no screens.
@pragma('vm:entry-point')
void runAlertCheck() => Workmanager().executeTask((_, _) async {
  final container = ProviderContainer(overrides: await loadAppStart());
  try {
    await alertCheckOf(container).run();
  } finally {
    container.dispose();
  }
  return true;
});
