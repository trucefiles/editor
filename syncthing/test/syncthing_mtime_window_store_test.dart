import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const margin = SyncthingMtimeWindowStore.margin;
  late MemoryFileStore inner;
  late SyncthingMtimeWindowStore store;
  late DateTime now;
  late List<_FakeTimer> timers;

  setUp(() {
    inner = MemoryFileStore();
    now = DateTime(2026);
    timers = [];
    store = SyncthingMtimeWindowStore(
      inner,
      now: () => now,
      timer: (duration, callback) {
        final timer = _FakeTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    );
  });

  final note = path('a.md');

  Duration seconds(num value) => Duration(milliseconds: (value * 1000).round());

  /// Moves the clock forward by [by].
  void wait(num by) => now = now.add(seconds(by));

  /// Fires the pending rewrite timers and lets the rewrites run.
  Future<void> fireTimers() async {
    for (final timer in [...timers]) {
      timer.fire();
    }
    timers.clear();
    await pumpEventQueue();
  }

  List<_FakeTimer> pending() => [
    for (final timer in timers)
      if (timer.isActive) timer,
  ];

  FileVersion versionOnDisk() => inner.files[note]!.version;

  Future<FileEntry> write(String text, FileEntry? last) async =>
      (await (last == null
              ? store.create(note, bytesOf(text))
              : store.replace(note, bytesOf(text), ifUnchanged: last.version)))
          .value;

  test('a read waits for a write to the same file', () async {
    final held = _HeldWrites(inner);
    final serial = SyncthingMtimeWindowStore(held);
    final first = (await serial.create(note, bytesOf('v1'))).value;
    held.hold = Completer<void>();

    final writing = serial.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    );
    final reading = serial.read(note);
    held.hold!.complete();
    await writing;

    expect(String.fromCharCodes((await reading).value.bytes), 'v2');
  });

  test('rewrites a write within the window, a window after the earlier '
      'version', () async {
    final first = await write('v1', null);
    wait(1);
    final second = await write('v2', first);

    expect(pending().single.duration, seconds(1) + margin);
    await fireTimers();

    expect(inner.textOf('a.md'), 'v2');
    expect(versionOnDisk(), isNot(second.version));
  });

  test('rewrites writes of any size', () async {
    final first = await write('v1', null);
    await write('v22', first);

    expect(pending(), hasLength(1));
  });

  test('does not rewrite a write after the window', () async {
    final first = await write('v1', null);
    wait(2);
    final second = await write('v2', first);
    await fireTimers();

    expect(timers, isEmpty);
    expect(versionOnDisk(), second.version);
  });

  test('keeps one timer per file, due a window after the second-to-last '
      'write', () async {
    final first = await write('v1', null);
    wait(1);
    final second = await write('v2', first);
    wait(0.5);
    final third = await write('v3', second);

    // Due a window after the write at 1 s, not after the one at 1.5 s.
    expect(pending().single.duration, seconds(1.5) + margin);
    await fireTimers();

    expect(inner.textOf('a.md'), 'v3');
    // Three writes, then a single rewrite: the memory store counts them.
    expect(third.version, const FileVersion(3));
    expect(versionOnDisk(), const FileVersion(4));
  });

  test('keeps the version a caller got valid after the rewrite', () async {
    final first = await write('v1', null);
    final second = await write('v2', first);
    await fireTimers();
    wait(3);

    final third = await store.replace(
      note,
      bytesOf('v3!'),
      ifUnchanged: second.version,
    );

    expect(third, isA<Ok<FileEntry, StoreError>>());
    expect(inner.textOf('a.md'), 'v3!');
  });

  test('does not rewrite a file that changed meanwhile', () async {
    final first = await write('v1', null);
    await write('v2', first);
    final theirs = inner.put('a.md', 'xx');

    await fireTimers();

    expect(versionOnDisk(), theirs.version);
  });

  test('a delete cancels the rewrite', () async {
    final first = await write('v1', null);
    final second = await write('v2', first);

    await store.delete(note, ifUnchanged: second.version);

    expect(pending(), isEmpty);
  });

  test('rewrites a file created right after a delete', () async {
    final first = await write('v1', null);
    await store.delete(note, ifUnchanged: first.version);
    final created = await write('v2', null);

    await fireTimers();

    expect(versionOnDisk(), isNot(created.version));
  });

  test('counts a rewrite as an earlier version', () async {
    final first = await write('v1', null);
    final second = await write('v2', first);
    wait(2.1);
    await fireTimers();
    wait(0.5);

    await write('v3', second);

    expect(pending().single.duration, seconds(1.5) + margin);
  });

  test('counts versions it read, written by others', () async {
    // Another app wrote the file 1 s ago.
    inner.files[note] = FileContent(
      bytesOf('theirs'),
      version: const FileVersion('theirs'),
      modified: now.subtract(seconds(1)),
    );
    final read = (await store.read(note)).value;

    await store.replace(note, bytesOf('mine!!'), ifUnchanged: read.version);

    expect(pending().single.duration, seconds(1) + margin);
  });

  test('ignores old versions it read', () async {
    inner.files[note] = FileContent(
      bytesOf('old'),
      version: const FileVersion('old'),
      modified: now.subtract(const Duration(hours: 1)),
    );
    final read = (await store.read(note)).value;

    await store.replace(note, bytesOf('new'), ifUnchanged: read.version);

    expect(timers, isEmpty);
  });

  test('counts versions read from a clock slightly ahead', () async {
    inner.files[note] = FileContent(
      bytesOf('theirs'),
      version: const FileVersion('theirs'),
      modified: now.add(seconds(1)),
    );
    final read = (await store.read(note)).value;

    await store.replace(note, bytesOf('mine!!'), ifUnchanged: read.version);

    expect(pending().single.duration, seconds(3) + margin);
  });

  test('ignores versions read from a clock far ahead', () async {
    inner.files[note] = FileContent(
      bytesOf('theirs'),
      version: const FileVersion('theirs'),
      modified: now.add(const Duration(hours: 1)),
    );
    final read = (await store.read(note)).value;

    await store.replace(note, bytesOf('mine!!'), ifUnchanged: read.version);

    expect(timers, isEmpty);
  });

  test('keeps files apart', () async {
    await write('v1', null);
    await store.create(path('b.md'), bytesOf('v1'));

    expect(timers, isEmpty);
  });

  test('logs each rewrite', () async {
    final records = <LogRecord>[];
    final logs = Logger.root.onRecord.listen(records.add);
    addTearDown(logs.cancel);
    final first = await write('v1', null);
    await write('v2', first);

    await fireTimers();

    expect(records.single.message, contains('Rewrote a.md'));
  });
}

/// A timer the test fires by hand.
final class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Holds writes to [_inner] while [hold] is pending.
final class _HeldWrites implements FileStore {
  _HeldWrites(this._inner);

  final FileStore _inner;
  Completer<void>? hold;

  @override
  Future<Result<FileEntry, StoreError>> create(
    RelPath path,
    Uint8List bytes,
  ) async {
    await hold?.future;
    return _inner.create(path, bytes);
  }

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) async {
    await hold?.future;
    return _inner.replace(path, bytes, ifUnchanged: ifUnchanged);
  }

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _inner.delete(path, ifUnchanged: ifUnchanged);

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _inner.list(enterFolder: enterFolder, includeFile: includeFile);

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _inner.read(path);
}
