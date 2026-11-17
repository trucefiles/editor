import 'package:truce_calendar/truce_calendar.dart' show ItemKind;
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';

/// An event's alert titled [title], ringing at [at], for an event from
/// [start] to [end] (on this device's clock; by default the hour from
/// [at]) in `work.ics`.
PlannedAlert eventAlert(
  String title, {
  required DateTime at,
  DateTime? start,
  DateTime? end,
}) => PlannedAlert(
  id: 'fake:a/work.ics|$title',
  file: (folder: const FolderId('fake', 'a'), path: RelPath.parse('work.ics')!),
  at: at,
  title: title,
  kind: ItemKind.event,
  uid: title,
  start: (start ?? at).toLocal(),
  end: (end ?? at.add(const Duration(hours: 1))).toLocal(),
);
