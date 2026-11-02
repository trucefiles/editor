import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// The time zone [zone] (an IANA name) as the `timezone` data has it;
/// `null` if the data doesn't know it (e.g. a Windows name).
tz.Location? locationOf(String zone) {
  if (!_zonesLoaded) {
    zones.initializeTimeZones();
    _zonesLoaded = true;
  }
  return tz.timeZoneDatabase.locations[zone];
}

/// The time zone database, loaded once when first needed: the
/// `timezone` package keeps it in one place for the whole program.
bool _zonesLoaded = false;
