/// [system] as Linux answers it: the time zone package names `UTC` when
/// it can't tell (e.g. a sandbox without `timedatectl` or
/// `/etc/timezone`), so that is taken as unknown; a system really on UTC
/// names it `Etc/UTC`.
Future<String?> Function() linuxZone(Future<String?> Function() system) =>
    () async {
      final zone = await system();
      return zone == 'UTC' ? null : zone;
    };
