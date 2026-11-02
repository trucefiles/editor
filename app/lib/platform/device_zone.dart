import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// This device's time zone, as the system names it (an IANA name, e.g.
/// `Europe/Berlin`); `null` if the system can't tell. Asked anew each
/// time, so a trip shows.
Future<String?> deviceZone() async {
  try {
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    // On Linux the package answers `UTC` when it can't tell (e.g. a
    // sandbox without `timedatectl` or `/etc/timezone`); a system really
    // on UTC names it `Etc/UTC`.
    return zone == 'UTC' ? null : zone;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  } on ArgumentError {
    // The package reports a system that names no zone only so.
    return null;
  }
}
