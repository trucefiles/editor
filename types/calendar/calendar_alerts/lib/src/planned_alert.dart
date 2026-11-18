import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// One alert as planned to ring: what the ringer shows and what a tap on
/// it opens, as plain values, so it outlives the calendar read it came
/// from (e.g. in a notification the system holds).
final class PlannedAlert {
  const PlannedAlert({
    required this.id,
    required this.file,
    required this.at,
    required this.title,
    required this.kind,
    required this.uid,
    this.date,
    this.start,
    this.end,
    this.allDay = false,
  });

  /// [alert] of the calendar [file].
  PlannedAlert.of(FileKey file, Alert alert)
    : this(
        id: idOf(file, alert),
        file: file,
        at: alert.at,
        title: alert.title,
        kind: switch (alert.item) {
          CalendarEvent() => ItemKind.event,
          CalendarTask() => ItemKind.task,
        },
        uid: alert.item.uid,
        date: alert.recurrence?.local,
        start: alert.start,
        end: alert.end,
        allDay: alert.part.allDay,
      );

  /// The id of [alert] of [file], unique among every calendar's.
  static String idOf(FileKey file, Alert alert) =>
      '${file.folder.storageName}/${file.path.value}|${alert.key}';

  final String id;

  /// The calendar it is from.
  final FileKey file;

  /// When it rings (UTC).
  final DateTime at;

  final String title;

  /// Whether it is an event's or a task's.
  final ItemKind kind;
  final String uid;

  /// Which date of a repeating item it is for (on this device's clock);
  /// `null` for one that doesn't repeat.
  final DateTime? date;

  /// When its date starts and ends (a task's: its due time) on this
  /// device's clock; `null` for a task without a due date.
  final DateTime? start;
  final DateTime? end;

  /// Whether its date is a whole day.
  final bool allDay;

  /// Whether it is still worth telling at [now], should it have been
  /// missed: an event's until it ends, an open task's always.
  bool relevantAt(DateTime now) =>
      kind == ItemKind.task || end == null || end!.isAfter(now);

  Map<String, Object?> toJson() => {
    'id': id,
    'folder': [file.folder.plugin, file.folder.folder],
    'path': file.path.value,
    'at': at.toUtc().toIso8601String(),
    'title': title,
    'kind': kind.name,
    'uid': uid,
    'date': date?.toUtc().toIso8601String(),
    'start': start?.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
    'allDay': allDay,
  };

  /// The alert [json] holds, as [toJson] writes it; `null` if it holds
  /// none.
  static PlannedAlert? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'folder': [final String plugin, final String folder],
      'path': final String path,
      'at': final String at,
      'title': final String title,
      'kind': final String kind,
      'uid': final String uid,
    }) {
      final (folderId, relPath, time, itemKind) = (
        FolderId.parse(plugin, folder),
        RelPath.parse(path),
        DateTime.tryParse(at),
        ItemKind.values.asNameMap()[kind],
      );
      if (folderId == null ||
          relPath == null ||
          time == null ||
          itemKind == null) {
        return null;
      }
      DateTime? timeAt(String name) => switch (json[name]) {
        final String text => DateTime.tryParse(text)?.toLocal(),
        _ => null,
      };
      return PlannedAlert(
        id: id,
        file: (folder: folderId, path: relPath),
        at: time.toUtc(),
        title: title,
        kind: itemKind,
        uid: uid,
        date: timeAt('date'),
        start: timeAt('start'),
        end: timeAt('end'),
        allDay: json['allDay'] == true,
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PlannedAlert &&
      other.id == id &&
      other.file == file &&
      other.at == at &&
      other.title == title &&
      other.kind == kind &&
      other.uid == uid &&
      other.date == date &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay;

  @override
  int get hashCode =>
      Object.hash(id, file, at, title, kind, uid, date, start, end, allDay);
}
