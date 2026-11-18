import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart'
    show deviceZoneNow;
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../calendar_tab/calendar_tab_controller.dart';
import '../file_types/file_types.dart';
import '../files/file_settings_controller.dart';
import '../folder_state/folder_state_wiring.dart';
import '../folders/folders_controller.dart';
import '../platform/platform_wiring.dart';
import 'alert_check.dart';
import 'alerts_wiring.dart';

/// The background check of the alerts on the app's own wiring in
/// [container], with no screens: no draft recovery, no pruning, nothing
/// written into the folders.
AlertCheck alertCheckOf(ProviderContainer container) => AlertCheck(
  role: container.read(plannerRoleProvider),
  planner: () => AlertPlanner(
    ringer: container.read(ringerProvider),
    store: container.read(ringStateStoreProvider),
  ),
  listShown: () => _shownFiles(container),
  read: (files) async => {
    for (final MapEntry(key: file, value: (:calendar, title: _))
        in (await container.read(calendarReadsProvider).readAll(files)).entries)
      file: calendar,
  },
  zone: deviceZoneNow,
);

/// The calendars shown in the Calendar tab, as one listing of every
/// folder finds them now.
Future<ShownFiles> _shownFiles(ProviderContainer container) async {
  final folders = await container.read(foldersProvider.future);
  final owner = container.read(folderStateOwnerProvider)
    ..send(FoldersChanged({for (final folder in folders) folder.id}));
  await ask<FolderStateInput, Fresh>(owner.send, owner.events, Refresh.new);
  final settings = await container.read(fileSettingsStoreProvider).load();
  final listed = FolderFiles(
    owner.state,
    folders: folders,
    types: container.read(fileTypesProvider),
  );
  return (
    files: [
      for (final file in listed.files)
        if (isShownCalendar(file, settingsIn(settings, file.key))) file,
    ],
    sees: seesIn(listed),
  );
}
