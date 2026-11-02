import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// [system] as Linux answers it: the time zone package names `UTC` when
/// it can't tell (e.g. a sandbox without `timedatectl` or
/// `/etc/timezone`), so that is taken as unknown; a system really on UTC
/// names it `Etc/UTC`.
DeviceZone linuxZone(DeviceZone system) => () async {
  final zone = await system();
  return zone == 'UTC' ? null : zone;
};
