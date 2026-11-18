import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart' show ItemKind;
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import '../../calendar_tab/ui/open_calendar.dart';
import '../../common/snack.dart';
import '../../folder_state/folder_state_controller.dart';

/// Opens [alert]'s event or task on its calendar's page, once the folders
/// are listed; says so if its calendar is gone.
Future<void> openAlert(
  BuildContext context,
  WidgetRef ref,
  PlannedAlert alert,
) async {
  final files = await ref.read(loadedFolderFiles);
  final file = files.files.firstWhereOrNull((file) => file.key == alert.file);
  if (!context.mounted) return;
  if (file == null) {
    return showSnack(context, 'The calendar of this alert is gone.');
  }
  await openCalendar(context, ref, file, switch (alert.kind) {
    ItemKind.event => EditOccurrence(
      alert.uid,
      alert.date,
      start: alert.start ?? alert.at.toLocal(),
    ),
    ItemKind.task => EditTask(alert.uid, alert.date, due: alert.start),
  });
}
