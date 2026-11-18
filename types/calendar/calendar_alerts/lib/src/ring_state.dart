import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'planned_alert.dart';

/// One alert handed to the ringer, under the number the ringer knows it
/// by.
typedef Handed = ({int number, PlannedAlert alert});

/// What a calendar's plan covers: its [version] (as text) read, the
/// next days from [day] (midnight on this device's clock; `null`: none,
/// it must be read again), in this device's time [zone].
typedef CalendarPlan = ({String version, DateTime? day, String zone});

/// What the planner keeps on this device between runs (in app storage,
/// never synced): the alerts handed to the ringer, what the plan of each
/// calendar they came from covers, and when the app last could ring.
final class RingState {
  const RingState({
    this.handed = const {},
    this.nextNumber = 1,
    this.plans = const {},
    this.lastAlive,
  });

  /// Nothing planned yet.
  static const none = RingState();

  /// The alerts handed to the ringer, by id.
  final Map<String, Handed> handed;

  /// The number the next alert handed gets: each alert keeps its own
  /// while it is planned, and a number is not given twice soon, so a
  /// notification that rang never stands for another alert.
  final int nextNumber;

  /// Each calendar planned from, with what its plan covers.
  final Map<FileKey, CalendarPlan> plans;

  /// When something last could ring alerts here: alerts after it that
  /// weren't handed to a ringer that rings on its own were missed.
  final DateTime? lastAlive;

  /// Whether the calendar [file], as listed at [version], must be read
  /// for a plan at [now] in [zone]: its plan doesn't cover that version,
  /// day and zone.
  bool needsRead(
    FileKey file,
    String version, {
    required DateTime now,
    required String zone,
  }) => plans[file] != (version: version, day: dayOf(now), zone: zone);

  RingState copyWith({
    Map<String, Handed>? handed,
    int? nextNumber,
    Map<FileKey, CalendarPlan>? plans,
    DateTime? lastAlive,
  }) => RingState(
    handed: handed ?? this.handed,
    nextNumber: nextNumber ?? this.nextNumber,
    plans: plans ?? this.plans,
    lastAlive: lastAlive ?? this.lastAlive,
  );

  /// Equal when it keeps the same: a step that changes nothing saves
  /// nothing.
  @override
  bool operator ==(Object other) =>
      other is RingState &&
      const MapEquality<String, Handed>().equals(other.handed, handed) &&
      other.nextNumber == nextNumber &&
      const MapEquality<FileKey, CalendarPlan>().equals(other.plans, plans) &&
      other.lastAlive == lastAlive;

  @override
  int get hashCode => Object.hash(
    const MapEquality<String, Handed>().hash(handed),
    nextNumber,
    const MapEquality<FileKey, CalendarPlan>().hash(plans),
    lastAlive,
  );

  Map<String, Object?> toJson() => {
    'handed': [
      for (final (:number, :alert) in handed.values)
        {'number': number, 'alert': alert.toJson()},
    ],
    'nextNumber': nextNumber,
    'plans': [
      for (final MapEntry(key: file, value: (:version, :day, :zone))
          in plans.entries)
        {
          'folder': [file.folder.plugin, file.folder.folder],
          'path': file.path.value,
          'version': version,
          'day': day?.toIso8601String(),
          'zone': zone,
        },
    ],
    'lastAlive': lastAlive?.toUtc().toIso8601String(),
  };

  /// The state [json] holds, as [toJson] writes it; each part read on its
  /// own, a broken one as none.
  static RingState fromJson(Object? json) {
    final fields = json is Map<String, Object?>
        ? json
        : const <String, Object?>{};
    final handed = <String, Handed>{
      for (final entry in _list(fields['handed']))
        if (entry case {'number': final int number, 'alert': final alert})
          if (PlannedAlert.fromJson(alert) case final alert?)
            alert.id: (number: number, alert: alert),
    };
    return RingState(
      handed: handed,
      nextNumber: switch (fields['nextNumber']) {
        final int next => next,
        // Past every number given, so none is given twice.
        _ => (handed.values.map((each) => each.number).maxOrNull ?? 0) + 1,
      },
      plans: {
        for (final entry in _list(fields['plans']))
          if (entry case {
            'folder': [final String plugin, final String folder],
            'path': final String path,
            'version': final String version,
            'zone': final String zone,
          })
            if ((FolderId.parse(plugin, folder), RelPath.parse(path)) case (
              final folder?,
              final path?,
            ))
              (folder: folder, path: path): (
                version: version,
                day: _timeOf(entry['day']),
                zone: zone,
              ),
      },
      lastAlive: _timeOf(fields['lastAlive'])?.toLocal(),
    );
  }

  static List<Object?> _list(Object? json) =>
      json is List<Object?> ? json : const [];

  static DateTime? _timeOf(Object? json) =>
      json is String ? DateTime.tryParse(json) : null;
}

/// The day of [time], at midnight on this device's clock.
DateTime dayOf(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}
