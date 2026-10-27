import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../scan/folder_scans.dart';
import '../scan/folder_scans_controller.dart';

/// One compare screen's flow: shows what its compare owner shows, passes
/// each scan on to it, and asks it to keep a side. Each kind of
/// comparison (a conflict, a backup) says where its sides come from and
/// what comes next.
abstract class CompareController<Target, Sides>
    extends Notifier<CompareState<Target, Sides>> {
  CompareController(this.start);

  /// What the screen opened with.
  final Target start;

  late CompareOwner<Target, Sides> _owner;

  /// Whether a keep that worked goes on to what a later scan finds.
  bool get goesOn;

  /// Where the sides come from and where keeps go. Made once per screen,
  /// so a keep under way when the screen closes still ends and rescans.
  CompareSource<Target, Sides> source();

  /// What [scans] found to compare next; `null` if nothing.
  Target? nextIn(FolderScans scans);

  @override
  CompareState<Target, Sides> build() {
    final owner = _owner = compareOwner(start, source(), goesOn: goesOn);
    final changes = owner.changes.listen((shown) => state = shown);
    ref
      ..listen(folderScansProvider, (_, next) {
        if (next.value case final scans?) {
          owner.send(ScanSeen(nextIn(scans), startedAt: scans.startedAt));
        }
      })
      ..onDispose(() {
        unawaited(changes.cancel());
        unawaited(owner.close());
      });
    return owner.state;
  }

  /// Keeps [choice] of what shows; answered once a scan after the keep
  /// told what comes next. `null` if the screen closed first.
  Future<KeepAnswer?> keep(Resolution choice) =>
      ask<CompareInput<Target, Sides>, KeepAnswer>(
        _owner.send,
        _owner.events,
        (ticket) => Keep(ticket, choice),
      );
}
