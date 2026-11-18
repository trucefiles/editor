/// When the alerts of the calendars shown on this device ring: the
/// planner ([AlertPlanner]) keeps the alerts of the next days handed to a
/// [Ringer] (the system's notifications, or the app's own clock), moves
/// them on each day, and tells the alerts missed while nothing could ring
/// them. What it planned is kept in a [RingState] in app storage, never in
/// the synced files.
///
/// Pure Dart, no UI and no platform; the ringer and the store are handed
/// in from above.
library;

export 'src/alert_planner.dart';
export 'src/planned_alert.dart';
export 'src/planner_contract.dart';
export 'src/ring_state.dart';
export 'src/ringer.dart';
