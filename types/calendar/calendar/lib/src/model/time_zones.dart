import 'package:collection/collection.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// The time zone [zone] (an IANA name) as the `timezone` data has it;
/// `null` if the data doesn't know it (e.g. a Windows name).
tz.Location? locationOf(String zone) => _database.locations[zone];

/// Every time zone the `timezone` data knows (IANA names), by name.
List<String> zoneNames() => _database.locations.keys.sorted();

/// The time zone database, loaded when first needed: the `timezone`
/// package keeps it in one place for the whole program.
final tz.LocationDatabase _database = () {
  zones.initializeTimeZones();
  return tz.timeZoneDatabase;
}();
