import 'package:truce_calendar/truce_calendar.dart' show Calendar;
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_files/truce_files.dart';

import 'app_alerts.dart';
import 'planner_role.dart';

/// The calendars shown on this device, as one listing of every folder
/// finds them now, and what that listing [sees].
typedef ShownFiles = ({
  List<ListedFile> files,
  bool Function(FileKey key) sees,
});

/// One check of the alerts with no screen, as the background job runs
/// it: it lists the shown calendars, reads those that changed or that a
/// new day needs, plans them and ends. It only reads: it writes nothing
/// into the folders; only the planner keeps its state. If another part
/// plans (the app), it asks it to plan again instead.
final class AlertCheck {
  /// [planner] makes this run's planner; [listShown] lists the shown
  /// calendars; [read] reads some of them (`null`: can't be read);
  /// [zone] tells this device's time zone.
  AlertCheck({
    required this._role,
    required this._planner,
    required this._listShown,
    required this._read,
    required this._zone,
  });

  final PlannerRole _role;
  final AlertPlanner Function() _planner;
  final Future<ShownFiles> Function() _listShown;
  final Future<Map<ListedFile, Calendar?>> Function(List<ListedFile> files)
  _read;
  final String Function() _zone;

  Future<void> run() async {
    if (!await _role.takeOrAsk()) return;
    final planner = _planner();
    try {
      await planner.handle(
        (ticket) => Started(now: DateTime.now(), ticket: ticket),
      );
      final (:files, :sees) = await _listShown();
      // One moment for what to read and the plan: alerts whose time came
      // meanwhile ring at once.
      final (now, zone) = (DateTime.now(), _zone());
      final ring = planner.state.ring;
      final read = await _read([
        for (final file in files)
          if (ring.needsRead(file.key, file.version.text, now: now, zone: zone))
            file,
      ]);
      await planner.handle(
        (ticket) => CalendarsListed(
          now: now,
          zone: zone,
          calendars: {
            for (final file in files)
              file.key: listedCalendar(file, read[file]),
          },
          sees: sees,
          ticket: ticket,
        ),
      );
      await planner.handle(
        (ticket) => Stopping(now: DateTime.now(), ticket: ticket),
      );
    } finally {
      await planner.close();
      _role.release();
    }
  }
}
