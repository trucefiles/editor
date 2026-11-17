import 'dart:io';

import 'package:logging/logging.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';

import '../storage/app_storage.dart';

final _log = Logger('alerts');

/// Keeps the alert planner's [RingState] in one JSON file in app storage
/// (never synced).
final class RingStateStore implements SettingStore<RingState> {
  RingStateStore(File file) : _file = JsonFile(file);

  /// The store of [storage].
  RingStateStore.of(AppStorage storage)
    : this(File('${storage.settingsPath}/ring_state.json'));

  final JsonFile _file;

  /// The kept state; none if nothing was kept or it can't be read.
  @override
  Future<RingState> load() async => switch (await _file.read()) {
    Ok(:final value) => RingState.fromJson(value),
    Err() => RingState.none,
  };

  /// Keeps [value]; where it can't be written (e.g. the disk is full),
  /// it logs why and the planner goes on with what it holds.
  @override
  Future<void> save(RingState value) async {
    if (await _file.write(value.toJson()) case Err(:final error)) {
      _log.warning("Couldn't keep the alerts' ring state: $error");
    }
  }
}
