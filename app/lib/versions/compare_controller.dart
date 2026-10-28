import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../folder_state/folder_contents.dart';
import '../folder_state/folder_state_controller.dart';

/// One compare screen's flow: shows what its compare owner shows, passes
/// what the folders hold on to it each time it changes, and asks it to
/// keep a side. Each kind of comparison (a conflict, a backup) says where
/// its sides come from and what comes next.
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

  /// The document compared.
  DocumentKey get document;

  /// What [contents] hold to compare next; `null` if nothing.
  Target? nextIn(FolderContents contents);

  @override
  CompareState<Target, Sides> build() {
    final owner = _owner = compareOwner(start, source(), goesOn: goesOn);
    final changes = owner.changes.listen((shown) => state = shown);
    ref
      ..listen(folderContentsProvider, (_, next) {
        if (next.value case final contents?) {
          if (contents.seenAt(document) case final seenAt?) {
            owner.send(ScanSeen(nextIn(contents), startedAt: seenAt));
          }
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
