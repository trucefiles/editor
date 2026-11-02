import '../changes/folder_changes.dart';
import '../common/moment.dart';
import '../common/result.dart';
import '../marks/file_marks.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../owners/machine.dart';
import '../plugins/folder_id.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'folder_state.dart';
import 'folder_state_contract.dart';
import 'folder_state_work.dart';

/// How long changes wait: until they pause for [settle], at most
/// [longest] after the first.
typedef ChangesTiming = ({Duration settle, Duration longest});

/// The folder state owner's decision on [message] in [state], with its
/// [work]: one listing or check at a time, whole listings first; every
/// [Refresh] answered once each folder was listed since.
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
      work.folders != null &&
      (work.listDue.isNotEmpty || work.checkDue.isNotEmpty))
    'a listing or check is due, but none runs',
  if (!work.active && (work.changes != null || work.hinted.isNotEmpty))
    'changes wait while not in use',
  if (work.folders case final followed?
      when !state.folders.keys.every(followed.contains) ||
          !followed.every(state.folders.containsKey))
    'the state holds other folders than those followed',
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
      case FoldersChanged(:final folders):
        _foldersChanged(folders);
      case Hinted(:final folder, :final hint)
          when work.active && _follows(folder):
        _hinted(folder, hint);
      case Hinted():
        break;
      case AppWrote(:final folder, :final paths, :final at)
          when _follows(folder):
        _wrote(folder, paths, at);
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

  bool _follows(FolderId folder) => work.folders?.contains(folder) ?? false;

  // Inputs.

  void _refresh(Ticket ticket) {
    final followed = work.folders;
    if (followed == null) {
      work = work.copyWith(early: [...work.early, ticket]);
      return;
    }
    _waitFor(ticket, followed);
  }

  /// [ticket] is answered once each of [folders] was listed since.
  void _waitFor(Ticket ticket, Set<FolderId> folders) {
    if (folders.isEmpty) return events.add(Fresh(ticket));
    work = work.copyWith(
      refreshes: [...work.refreshes, (ticket: ticket, left: folders)],
      listDue: {...work.listDue, ...folders},
    );
  }

  void _foldersChanged(Set<FolderId> folders) {
    final before = work.folders ?? const {};
    bool kept(FolderId folder) => folders.contains(folder);
    state = FolderState({
      for (final folder in folders)
        folder: state.folders[folder] ?? const NotListed(),
    });
    final early = work.early;
    work = work.copyWith(
      folders: folders,
      early: const [],
      listDue: {...work.listDue.where(kept), ...folders.difference(before)},
      checkDue: _keptOf(work.checkDue, kept),
      hinted: _keptOf(work.hinted, kept),
      ownWrites: _keptOf(work.ownWrites, kept),
    );
    _setRefreshes([
      for (final (:ticket, :left) in work.refreshes)
        (ticket: ticket, left: left.where(kept).toSet()),
    ]);
    for (final ticket in early) {
      _waitFor(ticket, folders);
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

  void _hinted(FolderId folder, ChangeHint hint) {
    switch (hint) {
      case ListAgain():
        work = work.copyWith(listDue: {...work.listDue, folder});
      case PathChanged(:final path):
        work = work.copyWith(hinted: _adding(work.hinted, folder, {path}));
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
    checkDue: work.hinted.entries.fold<Map<FolderId, Set<RelPath>>>(
      work.checkDue,
      (due, hinted) => _adding(due, hinted.key, hinted.value),
    ),
    hinted: const {},
    changes: null,
  );

  void _wrote(FolderId folder, Set<RelPath> paths, DateTime at) {
    work = work.copyWith(
      checkDue: _adding(work.checkDue, folder, paths),
      ownWrites: {
        ...work.ownWrites,
        folder: {
          ...?work.ownWrites[folder],
          for (final path in paths) path: at,
        },
      },
    );
  }

  // Results.

  void _listed(Result<WholeListing, StoreError> listing, Moment startedAt) {
    final running = work.running!;
    final folder = running.folder;
    work = work.copyWith(running: null);
    _setRefreshes([
      for (final (:ticket, :left) in work.refreshes)
        (
          ticket: ticket,
          left: running.answers.contains(ticket)
              ? left.difference({folder})
              : left,
        ),
    ]);
    if (!_follows(folder)) return;
    switch (listing) {
      case Ok(value: (:final scan, :final marks)):
        final files = _shown(folder, {
          for (final entry in scan.files) entry.path: entry,
        });
        _keepOwnWritesOf(folder, files);
        _setFolder(
          folder,
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
        _setFolder(folder, ListingFailed(error));
    }
  }

  void _checked(
    Result<PartScan, StoreError> part,
    MarksFiles? marks,
    Moment startedAt,
  ) {
    final running = work.running!;
    work = work.copyWith(running: null);
    final folder = running.folder;
    final listed = state.folders[folder];
    // A folder not listed yet, or failed, waits for a listing: a check
    // tells too little.
    if (listed is! Listed) return;
    var checked = listed;
    if (marks != null) checked = checked.copyWith(marks: marks);
    switch (part) {
      case Ok(value: final part):
        checked = _mergePart(
          folder,
          checked,
          part,
          asked: running.checked!,
          startedAt: startedAt,
        );
      case Err():
        // What changed there is still unknown: a listing finds it.
        work = work.copyWith(listDue: {...work.listDue, folder});
    }
    _setFolder(folder, checked);
  }

  /// [listed] with what [part] found in the folders [asked]: what lies
  /// directly in those found, and nothing in or below those gone.
  Listed _mergePart(
    FolderId folder,
    Listed listed,
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
    final files = _shown(folder, {
      for (final MapEntry(:key, :value) in listed.files.entries)
        if (!replaced(key)) key: value,
      for (final entry in part.files) entry.path: entry,
    });
    _keepOwnWritesOf(folder, files);
    return listed.copyWith(
      files: files,
      conflicts: {
        for (final MapEntry(:key, :value) in listed.conflicts.entries)
          if (!replaced(key)) key: value,
        for (final conflict in part.conflicts) conflict.mainPath: conflict,
      },
      subfolders: {
        for (final subfolder in listed.subfolders)
          if (!gone.any((f) => _inOrAt(subfolder, f))) subfolder,
        for (final subfolder in part.found) ?subfolder,
      },
      checkedAt: {
        ...listed.checkedAt,
        for (final subfolder in known) subfolder: startedAt,
      },
    );
  }

  /// Whether [path] is [folder] or inside it; anything is inside the top
  /// level (`null`).
  static bool _inOrAt(RelPath path, RelPath? folder) =>
      folder == null || path.isAtOrInside(folder);

  /// [files] as shown: a file's time is never older than the app's own
  /// last write of it.
  Map<RelPath, FileEntry> _shown(
    FolderId folder,
    Map<RelPath, FileEntry> files,
  ) {
    final writes = work.ownWrites[folder] ?? const {};
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
  void _keepOwnWritesOf(FolderId folder, Map<RelPath, FileEntry> files) {
    final writes = work.ownWrites[folder];
    if (writes == null) return;
    final kept = {
      for (final MapEntry(key: path, value: at) in writes.entries)
        if (files[path] case final entry? when !entry.modified.isAfter(at))
          path: at,
    };
    work = work.copyWith(ownWrites: {...work.ownWrites, folder: kept});
  }

  void _setFolder(FolderId folder, ListingState listing) =>
      state = FolderState({...state.folders, folder: listing});

  // The next listing or check.

  /// Starts the next listing or check once none runs: whole listings
  /// first, as they find what checks would.
  void _next() {
    if (work.running != null || work.folders == null) return;
    if (work.listDue.isNotEmpty) {
      _list((work.listDue.toList()..sort()).first);
    } else if (work.checkDue.isNotEmpty) {
      _check((work.checkDue.keys.toList()..sort()).first);
    }
  }

  void _list(FolderId folder) {
    final id = _id();
    work = work.copyWith(
      running: (
        id: id,
        folder: folder,
        checked: null,
        answers: [
          for (final refresh in work.refreshes)
            if (refresh.left.contains(folder)) refresh.ticket,
        ],
      ),
      listDue: {...work.listDue}..remove(folder),
      // The listing finds what the checks would.
      checkDue: {...work.checkDue}..remove(folder),
    );
    effects.add(ListWhole(id, folder, marks: _marksOf(folder)));
  }

  void _check(FolderId folder) {
    final paths = work.checkDue[folder]!;
    final marksFiles = paths.where(FileMarks.files.includesFile).toSet();
    final checked = {
      for (final path in paths)
        if (!marksFiles.contains(path)) path.parent,
    };
    final id = _id();
    work = work.copyWith(
      running: (
        id: id,
        folder: folder,
        checked: checked,
        answers: const <Ticket>[],
      ),
      checkDue: {...work.checkDue}..remove(folder),
    );
    effects.add(
      CheckPart(
        id,
        folder,
        folders: checked,
        marksFiles: marksFiles,
        marks: _marksOf(folder),
      ),
    );
  }

  MarksFiles _marksOf(FolderId folder) => switch (state.folders[folder]) {
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

  static Map<FolderId, V> _keptOf<V>(
    Map<FolderId, V> byFolder,
    bool Function(FolderId folder) kept,
  ) => {
    for (final MapEntry(:key, :value) in byFolder.entries)
      if (kept(key)) key: value,
  };

  static Map<FolderId, Set<RelPath>> _adding(
    Map<FolderId, Set<RelPath>> byFolder,
    FolderId folder,
    Set<RelPath> paths,
  ) => {
    ...byFolder,
    folder: {...?byFolder[folder], ...paths},
  };
}
