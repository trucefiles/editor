/// When the editor's text goes from memory to the draft and to the
/// folder: one clock, so the order is always memory → draft → folder.
library;

import 'package:collection/collection.dart';

/// The clock's timers.
enum SaveTimer {
  /// After the last keypress, restarted by typing: a draft.
  pause(Duration(seconds: 3)),

  /// From the first keypress after a draft, cancelled by a draft: a
  /// draft while typing goes on.
  long(Duration(seconds: 30)),

  /// After a pause's draft, cancelled by a keypress: into the folder.
  folder(Duration(seconds: 30)),

  /// From the first keypress after the folder got the text: once it
  /// fires, the next pause's draft goes into the folder too.
  stale(Duration(minutes: 2));

  const SaveTimer(this.delay);

  final Duration delay;
}

/// Where the text goes when a timer fires.
enum Save {
  /// Into the draft.
  draft,

  /// Into the folder, through the draft.
  folder,
}

/// A timer to start: [timer] with the id its firing comes back with.
typedef StartedTimer = ({SaveTimer timer, int id});

/// The clock after an event, the timers it starts, and the save due.
typedef Tick = ({SaveClock clock, List<StartedTimer> started, Save? save});

/// The save timing: which timers run, by the id of their last start, and
/// whether the text has waited long for the folder. Events go in, timers
/// to start and saves come out; a timer that fires after it was
/// restarted or cancelled does nothing.
final class SaveClock {
  const SaveClock() : this._(const {}, stale: false, nextId: 0);

  const SaveClock._(this._running, {required this.stale, required this.nextId});

  final Map<SaveTimer, int> _running;

  /// Whether the text has waited for the folder since [SaveTimer.stale].
  final bool stale;

  /// The id the next timer started gets.
  final int nextId;

  /// A keypress that changed the text.
  Tick typed() => _tick(
    start: {
      SaveTimer.pause,
      if (!_running.containsKey(SaveTimer.long)) SaveTimer.long,
      if (!stale && !_running.containsKey(SaveTimer.stale)) SaveTimer.stale,
    },
    stop: {SaveTimer.folder},
  );

  /// Timer [id] fired.
  Tick fired(int id) => switch (_running.entries
      .firstWhereOrNull((entry) => entry.value == id)
      ?.key) {
    null => _tick(),
    SaveTimer.pause when stale => _intoFolder({
      SaveTimer.pause,
      SaveTimer.long,
    }),
    SaveTimer.pause => _tick(
      start: {SaveTimer.folder},
      stop: {SaveTimer.pause, SaveTimer.long},
      save: Save.draft,
    ),
    SaveTimer.long => _tick(stop: {SaveTimer.long}, save: Save.draft),
    SaveTimer.folder => _intoFolder({SaveTimer.folder}),
    SaveTimer.stale => _tick(stop: {SaveTimer.stale}, stale: true),
  };

  /// The user left: the text went into the folder at once, and nothing
  /// waits.
  SaveClock get left => SaveClock._(const {}, stale: false, nextId: nextId);

  /// [stop] stopped, the text into the folder: no longer stale.
  Tick _intoFolder(Set<SaveTimer> stop) =>
      _tick(stop: {...stop, SaveTimer.stale}, stale: false, save: Save.folder);

  /// The clock with [stop] stopped and [start] started (anew), and
  /// [stale] if given, leading to [save].
  Tick _tick({
    Set<SaveTimer> start = const {},
    Set<SaveTimer> stop = const {},
    bool? stale,
    Save? save,
  }) {
    final started = [
      for (final (index, timer) in start.indexed)
        (timer: timer, id: nextId + index),
    ];
    return (
      clock: SaveClock._(
        {
          for (final MapEntry(:key, :value) in _running.entries)
            if (!stop.contains(key)) key: value,
          for (final (:timer, :id) in started) timer: id,
        },
        stale: stale ?? this.stale,
        nextId: nextId + started.length,
      ),
      started: started,
      save: save,
    );
  }
}
