import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../scan/folder_scans_controller.dart';
import 'conflict_sides.dart';
import 'folder_conflicts.dart';

final conflictProvider = NotifierProvider.autoDispose
    .family<ConflictController, ConflictState, FolderConflict>(
      ConflictController.new,
    );

/// Resolves one note's conflict copies one by one, oldest first. Loads the
/// sides of the oldest copy; after each resolve, moves on to the next copy
/// the rescan finds.
class ConflictController extends Notifier<ConflictState> {
  ConflictController(this._initial);

  final FolderConflict _initial;

  @override
  ConflictState build() {
    unawaited(_load(_initial));
    return ConflictState(_initial);
  }

  /// Keeps one side of the oldest copy and rescans. Does nothing while the
  /// sides load or a resolve runs.
  Future<KeepResult> keep(Resolution resolution) async {
    final ConflictState(:conflict, :sides) = state;
    if (sides is! Ok<ConflictSides, StoreError> || state.busy) {
      return (error: null, done: false);
    }
    state = ConflictState(conflict, sides: sides, busy: true);
    final resolved = await ref
        .read(folderServicesProvider(conflict.folder.location))
        .conflicts
        .resolve(conflict.conflict, sides.value.copy, resolution);
    await ref.read(folderScansProvider.notifier).refresh();
    if (!ref.mounted) return (error: null, done: true);
    final next = ref
        .read(folderScansProvider)
        .value
        ?.conflicts
        .forNote(conflict.key);
    final error = switch (resolved) {
      Ok() => null,
      Err(:final error) => error,
    };
    if (next == null) {
      state = ConflictState(conflict, sides: sides);
      return (error: error, done: true);
    }
    state = ConflictState(next);
    await _load(next);
    return (error: error, done: false);
  }

  Future<void> _load(FolderConflict conflict) async {
    final sides = await ConflictSides.load(
      ref.read(folderServicesProvider(conflict.folder.location)),
      conflict.conflict,
    );
    if (ref.mounted && state.conflict == conflict) {
      state = ConflictState(conflict, sides: sides);
    }
  }
}

/// What the conflict screen shows.
@immutable
final class ConflictState {
  const ConflictState(this.conflict, {this.sides, this.busy = false});

  final FolderConflict conflict;

  /// Both sides of the oldest copy; `null` while they load.
  final Result<ConflictSides, StoreError>? sides;

  /// A resolve is running; no other may start.
  final bool busy;
}

/// How a [ConflictController.keep] went. [done]: no copy is left, the
/// screen can close. [error]: why the resolve failed, if it did.
typedef KeepResult = ({ResolveError? error, bool done});
