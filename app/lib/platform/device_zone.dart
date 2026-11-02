import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// This device's time zone, as the system names it (an IANA name, e.g.
/// `Europe/Berlin`); `null` if the system can't tell. Asked anew each
/// time, so a trip shows.
Future<String?> systemZone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
    // The package tells of a system that names no zone only by throwing
    // this error; it is no bug here.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return null;
  }
}
