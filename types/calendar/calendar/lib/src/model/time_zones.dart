import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// The time zone [zone] (an IANA name) as the `timezone` data has it;
/// `null` if the data doesn't know it (e.g. a Windows name).
tz.Location? locationOf(String zone) => _database.locations[zone];

/// The time zones a person picks from: every place the `timezone` data
/// knows (IANA Area/City names), and `Etc/UTC`; by name. Left out are names
/// that are no place and read wrong, e.g. `Etc/GMT+5` (which is UTC−5)
/// or `EST5EDT`.
final List<String> zoneNames = [
  for (final zone in _database.locations.keys)
    if (zone == 'Etc/UTC' || (zone.contains('/') && !zone.startsWith('Etc/')))
      zone,
]..sort();

/// The time zone database, loaded when first needed: the `timezone`
/// package keeps it in one place for the whole program.
final tz.LocationDatabase _database = () {
  zones.initializeTimeZones();
  return tz.timeZoneDatabase;
}();
