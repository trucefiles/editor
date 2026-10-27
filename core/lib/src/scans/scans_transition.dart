import '../owners/effects.dart';
import '../owners/machine.dart';
import 'scans_contract.dart';
import 'scans_work.dart';

/// How long changes wait: until they pause for [settle], at most
/// [longest] after the first.
typedef ChangesTiming = ({Duration settle, Duration longest});

/// The scans owner's decision on [message] in [state] (the latest scan,
/// `null` before the first), with its [work]: never two scans at once,
/// and every [Refresh] answered by a scan that started after it.
Step<Scan?, ScansWork<Folder>, Fresh, ScansEffect<Folder, Scan>>
scansStep<Folder, Scan>(
  ChangesTiming timing,
  Scan? state,
  ScansWork<Folder> work,
  ScansMessage<Folder, Scan> message,
) {
  final step = _Step<Folder, Scan>(timing, state, work)..handle(message);
  return (
    state: step.state,
    work: step.work,
    events: step.events,
    effects: step.effects,
  );
}

/// How [work] breaks the scans owner's rules.
List<String> scansViolations<Folder, Scan>(
  Scan? state,
  ScansWork<Folder> work,
) => [
  if (work.running == null &&
      work.folders != null &&
      (work.due || work.waiting.isNotEmpty))
    'a scan is due, but none runs',
  if (!work.active && work.changes != null) 'changes wait while not in use',
];

final class _Step<Folder, Scan> {
  _Step(this.timing, this.state, this.work);

  final ChangesTiming timing;
  Scan? state;
  ScansWork<Folder> work;
  final events = <Fresh>[];
  final effects = <ScansEffect<Folder, Scan>>[];

  void handle(ScansMessage<Folder, Scan> message) {
    switch (message) {
      case Refresh(:final ticket):
        work = work.copyWith(waiting: [...work.waiting, ticket]);
      case FilesChanged() when work.active:
        _changed();
      case FilesChanged():
        break;
      case ChangesWaited(:final id)
          when id == work.changes?.settle || id == work.changes?.latest:
        work = work.copyWith(changes: null, due: true);
      case ChangesWaited():
        // A wait restarted or dropped since.
        break;
      case FoldersChanged(:final folders):
        work = work.copyWith(folders: folders, due: true);
      case Active(:final active):
        work = work.copyWith(
          active: active,
          changes: active ? work.changes : null,
        );
      case SettingChanged():
        work = work.copyWith(due: true);
      case Scanned(:final id, :final scan) when id == work.running?.id:
        state = scan;
        events.addAll([
          for (final ticket in work.running!.answers) Fresh(ticket),
        ]);
        work = work.copyWith(running: null);
      case Scanned():
        break;
    }
    _next();
  }

  /// Files changed: the scan waits until changes pause, at most a while
  /// after the first.
  void _changed() {
    final settle = _wait(timing.settle);
    final latest = work.changes?.latest ?? _wait(timing.longest);
    work = work.copyWith(changes: (settle: settle, latest: latest));
  }

  EffectId _wait(Duration delay) {
    final id = _id();
    effects.add(WaitForChanges(id, delay));
    return id;
  }

  /// Starts the scan due, once none runs and the folders are known.
  void _next() {
    final folders = work.folders;
    if (work.running != null || folders == null) return;
    if (!work.due && work.waiting.isEmpty) return;
    final id = _id();
    work = work.copyWith(
      running: (id: id, answers: work.waiting),
      waiting: const [],
      due: false,
    );
    effects.add(ScanAll(id, folders));
  }

  EffectId _id() {
    final id = EffectId(work.nextId);
    work = work.copyWith(nextId: work.nextId + 1);
    return id;
  }
}
