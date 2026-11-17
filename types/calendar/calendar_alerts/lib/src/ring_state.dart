import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'planned_alert.dart';

/// One alert handed to the ringer, under the number the ringer knows it
/// by.
typedef Handed = ({int number, PlannedAlert alert});

/// What the planner keeps on this device between runs (in app storage,
/// never synced): the alerts handed to the ringer, the version of each
/// calendar they were planned from, the day and time zone they were
/// planned in, and when the app last could ring.
final class RingState {
  const RingState({
    this.handed = const {},
    this.nextNumber = 1,
    this.versions = const {},
    this.plannedOn,
    this.zone,
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

  /// Each calendar planned from, with the version (as text) it was
  /// planned from.
  final Map<FileKey, String> versions;

  /// The day the alerts were planned for the next days, at midnight on
  /// this device's clock; `null` if never.
  final DateTime? plannedOn;

  /// This device's time zone then.
  final String? zone;

  /// When something last could ring alerts here: alerts after it that
  /// weren't handed to a ringer that rings on its own were missed.
  final DateTime? lastAlive;

  /// Whether the calendar [file], as listed at [version], must be read
  /// for a plan at [now] in [zone]: it changed since, or the plan must
  /// move on to a new day or zone.
  bool needsRead(
    FileKey file,
    String version, {
    required DateTime now,
    required String zone,
  }) => movesOn(now: now, zone: zone) || versions[file] != version;

  /// Whether a plan at [now] in [zone] covers new days, or another zone:
  /// every calendar is planned anew then.
  bool movesOn({required DateTime now, required String zone}) =>
      plannedOn != dayOf(now) || this.zone != zone;

  RingState copyWith({
    Map<String, Handed>? handed,
    int? nextNumber,
    Map<FileKey, String>? versions,
    DateTime? plannedOn,
    String? zone,
    DateTime? lastAlive,
  }) => RingState(
    handed: handed ?? this.handed,
    nextNumber: nextNumber ?? this.nextNumber,
    versions: versions ?? this.versions,
    plannedOn: plannedOn ?? this.plannedOn,
    zone: zone ?? this.zone,
    lastAlive: lastAlive ?? this.lastAlive,
  );

  Map<String, Object?> toJson() => {
    'handed': [
      for (final (:number, :alert) in handed.values)
        {'number': number, 'alert': alert.toJson()},
    ],
    'nextNumber': nextNumber,
    'versions': [
      for (final MapEntry(key: file, value: version) in versions.entries)
        {
          'folder': [file.folder.plugin, file.folder.folder],
          'path': file.path.value,
          'version': version,
        },
    ],
    'plannedOn': plannedOn?.toIso8601String(),
    'zone': zone,
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
      versions: {
        for (final entry in _list(fields['versions']))
          if (entry case {
            'folder': [final String plugin, final String folder],
            'path': final String path,
            'version': final String version,
          })
            if ((FolderId.parse(plugin, folder), RelPath.parse(path)) case (
              final folder?,
              final path?,
            ))
              (folder: folder, path: path): version,
      },
      plannedOn: _timeOf(fields['plannedOn']),
      zone: switch (fields['zone']) {
        final String zone => zone,
        _ => null,
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
