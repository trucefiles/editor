import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  const gap = Duration(seconds: 2);
  late MemoryFileStore inner;
  late RestampingFileStore store;
  late DateTime now;
  late List<Completer<void>> waits;

  setUp(() {
    inner = MemoryFileStore();
    now = DateTime(2026);
    waits = [];
    store = RestampingFileStore(
      inner,
      gap: gap,
      now: () => now,
      wait: (duration) {
        expect(duration, gap);
        final wait = Completer<void>();
        waits.add(wait);
        return wait.future;
      },
    );
  });

  final note = path('a.md');

  /// Lets the waits end and the rewrites run.
  Future<void> passGap() async {
    now = now.add(gap);
    for (final wait in waits) {
      wait.complete();
    }
    waits.clear();
    await pumpEventQueue();
  }

  FileVersion versionOnDisk() => inner.files[note]!.version;

  test('rewrites a same-size write within the gap after the gap', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    now = now.add(const Duration(seconds: 1));
    final second = (await store.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    )).value;

    await passGap();

    expect(inner.textOf('a.md'), 'v2');
    expect(versionOnDisk(), isNot(second.version));
  });

  test('does not rewrite a write of another size', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    final second = (await store.replace(
      note,
      bytesOf('v22'),
      ifUnchanged: first.version,
    )).value;

    await passGap();

    expect(waits, isEmpty);
    expect(versionOnDisk(), second.version);
  });

  test('does not rewrite a write after the gap', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    now = now.add(gap);
    final second = (await store.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    )).value;

    await passGap();

    expect(versionOnDisk(), second.version);
  });

  test('keeps the version a caller got valid after the rewrite', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    final second = (await store.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    )).value;
    await passGap();

    final third = await store.replace(
      note,
      bytesOf('v3!'),
      ifUnchanged: second.version,
    );

    expect(third, isA<Ok<FileEntry, StoreError>>());
    expect(inner.textOf('a.md'), 'v3!');
  });

  test('does not rewrite a file that changed meanwhile', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    await store.replace(note, bytesOf('v2'), ifUnchanged: first.version);
    final theirs = inner.put('a.md', 'xx');

    await passGap();

    expect(inner.textOf('a.md'), 'xx');
    expect(versionOnDisk(), theirs.version);
  });

  test('a later write replaces a pending rewrite', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    final second = (await store.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    )).value;
    now = now.add(const Duration(seconds: 1));
    final third = (await store.replace(
      note,
      bytesOf('v3-longer'),
      ifUnchanged: second.version,
    )).value;

    await passGap();

    expect(versionOnDisk(), third.version);
  });

  test('a delete cancels a pending rewrite', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    final second = (await store.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    )).value;
    await store.delete(note, ifUnchanged: second.version);

    await passGap();

    expect(inner.files, isEmpty);
  });

  test('rewrites a same-size file created right after a delete', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    await store.delete(note, ifUnchanged: first.version);
    final created = (await store.create(note, bytesOf('v2'))).value;

    await passGap();

    expect(inner.textOf('a.md'), 'v2');
    expect(versionOnDisk(), isNot(created.version));
  });

  test('counts the gap from the rewrite', () async {
    final first = (await store.create(note, bytesOf('v1'))).value;
    final second = (await store.replace(
      note,
      bytesOf('v2'),
      ifUnchanged: first.version,
    )).value;
    await passGap();

    final third = (await store.replace(
      note,
      bytesOf('v3'),
      ifUnchanged: second.version,
    )).value;
    await passGap();

    expect(inner.textOf('a.md'), 'v3');
    expect(versionOnDisk(), isNot(third.version));
  });

  test('keeps files apart', () async {
    await store.create(note, bytesOf('v1'));
    final other = (await store.create(path('b.md'), bytesOf('v1'))).value;

    await passGap();

    expect(waits, isEmpty);
    expect(inner.files[path('b.md')]!.version, other.version);
  });
}
