import '../changes/folder_changes.dart';
import '../common/moment.dart';
import '../common/result.dart';
import '../marks/document_marks.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../owners/machine.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import '../storage/selection.dart';
import 'folder_state.dart';
import 'folder_state_contract.dart';
import 'folder_state_work.dart';

/// How long changes wait: until they pause for [settle], at most
/// [longest] after the first.
typedef ChangesTiming = ({Duration settle, Duration longest});

/// The folder state owner's decision on [message] in [state], with its
/// [work]: one listing or check at a time, whole listings first; every
/// [Refresh] answered once each base folder was listed since.
Step<FolderState, FolderStateWork, Fresh, FolderStateEffect> folderStateStep(
  ChangesTiming timing,
  FolderState state,
  FolderStateWork work,
  FolderStateMessage message,
) {
  final step = _Step(timing, state, work)..handle(message);
  return (
    state: step.state,
    work: step.work,
    events: step.events,
    effects: step.effects,
  );
}

/// How [work] breaks the folder state owner's rules.
List<String> folderStateViolations(FolderState state, FolderStateWork work) => [
  if (work.running == null &&
      work.bases != null &&
      (work.listDue.isNotEmpty || work.checkDue.isNotEmpty))
    'a listing or check is due, but none runs',
  if (!work.active && (work.changes != null || work.hinted.isNotEmpty))
    'changes wait while not in use',
  if (work.bases case final bases?
      when !state.bases.keys.every(bases.containsKey) ||
          !bases.keys.every(state.bases.containsKey))
    'the state holds other base folders than those followed',
];

final class _Step {
  _Step(this.timing, this.state, this.work);

  final ChangesTiming timing;
  FolderState state;
  FolderStateWork work;
  final events = <Fresh>[];
  final effects = <FolderStateEffect>[];

  void handle(FolderStateMessage message) {
    switch (message) {
      case Refresh(:final ticket):
        _refresh(ticket);
      case BasesChanged(:final bases):
        _basesChanged(bases);
      case Hinted(:final baseId, :final hint)
          when work.active && _follows(baseId):
        _hinted(baseId, hint);
      case Hinted():
        break;
      case AppWrote(:final baseId, :final paths, :final at)
          when _follows(baseId):
        _wrote(baseId, paths, at);
      case AppWrote():
        break;
      case Active(:final active):
        work = work.copyWith(
          active: active,
          hinted: active ? work.hinted : const {},
          changes: active ? work.changes : null,
        );
      case ChangesWaited(:final id)
          when id == work.changes?.settle || id == work.changes?.latest:
        _changesPaused();
      case ChangesWaited():
        // A wait restarted or dropped since.
        break;
      case ListingDone(:final id, :final listing, :final startedAt)
          when id == work.running?.id:
        _listed(listing, startedAt);
      case CheckDone(:final id, :final part, :final marks, :final startedAt)
          when id == work.running?.id:
        _checked(part, marks, startedAt);
      case ListingDone() || CheckDone():
        break;
    }
    _next();
  }

  bool _follows(String baseId) => work.bases?.containsKey(baseId) ?? false;

  // Inputs.

  void _refresh(Ticket ticket) {
    final bases = work.bases;
    if (bases == null) {
      work = work.copyWith(early: [...work.early, ticket]);
      return;
    }
    _waitFor(ticket, bases.keys.toSet());
  }

  /// [ticket] is answered once each of [bases] was listed since.
  void _waitFor(Ticket ticket, Set<String> bases) {
    if (bases.isEmpty) return events.add(Fresh(ticket));
    work = work.copyWith(
      refreshes: [...work.refreshes, (ticket: ticket, left: bases)],
      listDue: {...work.listDue, ...bases},
    );
  }

  void _basesChanged(Map<String, Object> bases) {
    final before = work.bases ?? const {};
    bool kept(String baseId) => bases.containsKey(baseId);
    state = FolderState({
      for (final baseId in bases.keys)
        baseId: state.bases[baseId] ?? const NotListed(),
    });
    final early = work.early;
    work = work.copyWith(
      bases: bases,
      early: const [],
      listDue: {
        ...work.listDue.where(kept),
        for (final MapEntry(:key, :value) in bases.entries)
          if (before[key] != value) key,
      },
      checkDue: _keptOf(work.checkDue, kept),
      hinted: _keptOf(work.hinted, kept),
      ownWrites: _keptOf(work.ownWrites, kept),
    );
    _setRefreshes([
      for (final (:ticket, :left) in work.refreshes)
        (ticket: ticket, left: left.where(kept).toSet()),
    ]);
    for (final ticket in early) {
      _waitFor(ticket, bases.keys.toSet());
    }
  }

  /// Keeps [refreshes] that wait for a listing; answers the others.
  void _setRefreshes(List<WaitingRefresh> refreshes) {
    events.addAll([
      for (final (:ticket, :left) in refreshes)
        if (left.isEmpty) Fresh(ticket),
    ]);
    work = work.copyWith(
      refreshes: [
        for (final refresh in refreshes)
          if (refresh.left.isNotEmpty) refresh,
      ],
    );
  }

  void _hinted(String baseId, ChangeHint hint) {
    switch (hint) {
      case ListAgain():
        work = work.copyWith(listDue: {...work.listDue, baseId});
      case PathChanged(:final path):
        work = work.copyWith(hinted: _adding(work.hinted, baseId, {path}));
        _changed();
    }
  }

  /// Changes came: they wait until changes pause, at most a while after
  /// the first.
  void _changed() {
    final settle = _wait(timing.settle);
    final latest = work.changes?.latest ?? _wait(timing.longest);
    work = work.copyWith(changes: (settle: settle, latest: latest));
  }

  void _changesPaused() => work = work.copyWith(
    checkDue: work.hinted.entries.fold<Map<String, Set<RelPath>>>(
      work.checkDue,
      (due, hinted) => _adding(due, hinted.key, hinted.value),
    ),
    hinted: const {},
    changes: null,
  );

  void _wrote(String baseId, Set<RelPath> paths, DateTime at) {
    work = work.copyWith(
      checkDue: _adding(work.checkDue, baseId, paths),
      ownWrites: {
        ...work.ownWrites,
        baseId: {
          ...?work.ownWrites[baseId],
          for (final path in paths) path: at,
        },
      },
    );
  }

  // Results.

  void _listed(Result<BaseListing, StoreError> listing, Moment startedAt) {
    final running = work.running!;
    final baseId = running.baseId;
    work = work.copyWith(running: null);
    _setRefreshes([
      for (final (:ticket, :left) in work.refreshes)
        (
          ticket: ticket,
          left: running.answers.contains(ticket)
              ? left.difference({baseId})
              : left,
        ),
    ]);
    if (!_follows(baseId)) return;
    switch (listing) {
      case Ok(value: (:final scan, :final marks)):
        final files = _shown(baseId, {
          for (final entry in scan.files) entry.path: entry,
        });
        _keepOwnWritesOf(baseId, files);
        _setBase(
          baseId,
          Listed(
            files: files,
            conflicts: {
              for (final conflict in scan.conflicts)
                conflict.mainPath: conflict,
            },
            subfolders: scan.subfolders.toSet(),
            unreadable: scan.unreadable,
            marks: marks,
            listedAt: startedAt,
          ),
        );
      case Err(:final error):
        _setBase(baseId, ListingFailed(error));
    }
  }

  void _checked(
    Result<PartScan, StoreError> part,
    MarksFiles? marks,
    Moment startedAt,
  ) {
    final running = work.running!;
    work = work.copyWith(running: null);
    final baseId = running.baseId;
    final base = state.bases[baseId];
    // A base folder not listed yet, or failed, waits for a listing: a
    // check tells too little.
    if (base is! Listed) return;
    var checked = base;
    if (marks != null) checked = checked.copyWith(marks: marks);
    if (part case Ok(value: final part)) {
      checked = _mergePart(
        baseId,
        checked,
        part,
        asked: running.checked!,
        startedAt: startedAt,
      );
    }
    _setBase(baseId, checked);
  }

  /// [base] with what [part] found in the folders [asked]: what lies
  /// directly in those found, and nothing in or below those gone.
  Listed _mergePart(
    String baseId,
    Listed base,
    PartScan part, {
    required Set<RelPath?> asked,
    required Moment startedAt,
  }) {
    final gone = asked
        .where((f) => !part.found.contains(f) && !part.unknown.contains(f))
        .toSet();
    final known = {...part.found, ...gone};
    bool replaced(RelPath path) =>
        known.contains(path.parent) || gone.any((f) => _inOrAt(path, f));
    final files = _shown(baseId, {
      for (final MapEntry(:key, :value) in base.files.entries)
        if (!replaced(key)) key: value,
      for (final entry in part.files) entry.path: entry,
    });
    _keepOwnWritesOf(baseId, files);
    return base.copyWith(
      files: files,
      conflicts: {
        for (final MapEntry(:key, :value) in base.conflicts.entries)
          if (!replaced(key)) key: value,
        for (final conflict in part.conflicts) conflict.mainPath: conflict,
      },
      subfolders: {
        for (final folder in base.subfolders)
          if (!gone.any((f) => _inOrAt(folder, f))) folder,
        for (final folder in part.found) ?folder,
      },
      checkedAt: {
        ...base.checkedAt,
        for (final folder in known) folder: startedAt,
      },
    );
  }

  /// Whether [path] is [folder] or inside it; anything is inside the top
  /// level (`null`).
  static bool _inOrAt(RelPath path, RelPath? folder) =>
      folder == null || path == folder || Selection.isInside(path, folder);

  /// [files] as shown: a file's time is never older than the app's own
  /// last write of it.
  Map<RelPath, FileEntry> _shown(String baseId, Map<RelPath, FileEntry> files) {
    final writes = work.ownWrites[baseId] ?? const {};
    return {
      for (final MapEntry(key: path, value: entry) in files.entries)
        path: switch (writes[path]) {
          final at? when entry.modified.isBefore(at) => FileEntry(
            path,
            version: entry.version,
            modified: at,
          ),
          _ => entry,
        },
    };
  }

  /// Keeps the app's own writes only of [files] that don't show a later
  /// time yet; a write of a file that is gone is forgotten.
  void _keepOwnWritesOf(String baseId, Map<RelPath, FileEntry> files) {
    final writes = work.ownWrites[baseId];
    if (writes == null) return;
    final kept = {
      for (final MapEntry(key: path, value: at) in writes.entries)
        if (files[path] case final entry? when !entry.modified.isAfter(at))
          path: at,
    };
    work = work.copyWith(ownWrites: {...work.ownWrites, baseId: kept});
  }

  void _setBase(String baseId, BaseState base) =>
      state = FolderState({...state.bases, baseId: base});

  // The next listing or check.

  /// Starts the next listing or check once none runs: whole listings
  /// first, as they find what checks would.
  void _next() {
    if (work.running != null || work.bases == null) return;
    if (work.listDue.isNotEmpty) {
      _list((work.listDue.toList()..sort()).first);
    } else if (work.checkDue.isNotEmpty) {
      _check((work.checkDue.keys.toList()..sort()).first);
    }
  }

  void _list(String baseId) {
    final id = _id();
    work = work.copyWith(
      running: (
        id: id,
        baseId: baseId,
        checked: null,
        answers: [
          for (final refresh in work.refreshes)
            if (refresh.left.contains(baseId)) refresh.ticket,
        ],
      ),
      listDue: {...work.listDue}..remove(baseId),
      // The listing finds what the checks would.
      checkDue: {...work.checkDue}..remove(baseId),
    );
    effects.add(ListBase(id, baseId, marks: _marksOf(baseId)));
  }

  void _check(String baseId) {
    final paths = work.checkDue[baseId]!;
    final marksFiles = paths.where(DocumentMarks.files.includesFile).toSet();
    final folders = {
      for (final path in paths)
        if (!marksFiles.contains(path)) path.parent,
    };
    final id = _id();
    work = work.copyWith(
      running: (
        id: id,
        baseId: baseId,
        checked: folders,
        answers: const <Ticket>[],
      ),
      checkDue: {...work.checkDue}..remove(baseId),
    );
    effects.add(
      CheckBase(
        id,
        baseId,
        folders: folders,
        marksFiles: marksFiles,
        marks: _marksOf(baseId),
      ),
    );
  }

  MarksFiles _marksOf(String baseId) => switch (state.bases[baseId]) {
    Listed(:final marks) => marks,
    _ => MarksFiles.none,
  };

  EffectId _wait(Duration delay) {
    final id = _id();
    effects.add(WaitForChanges(id, delay));
    return id;
  }

  EffectId _id() {
    final id = EffectId(work.nextId);
    work = work.copyWith(nextId: work.nextId + 1);
    return id;
  }

  static Map<String, V> _keptOf<V>(
    Map<String, V> byBase,
    bool Function(String baseId) kept,
  ) => {
    for (final MapEntry(:key, :value) in byBase.entries)
      if (kept(key)) key: value,
  };

  static Map<String, Set<RelPath>> _adding(
    Map<String, Set<RelPath>> byBase,
    String baseId,
    Set<RelPath> paths,
  ) => {
    ...byBase,
    baseId: {...?byBase[baseId], ...paths},
  };
}
