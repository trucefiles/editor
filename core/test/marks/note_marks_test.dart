import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  const pinned = NoteMark(pinned: true);
  const teal = NoteMark(color: 'teal');

  late MemoryFileStore store;
  var clock = DateTime.utc(2026, 10, 13);

  /// The marks as device [id] sees them; each write is a second later.
  NoteMarks device(String id) => NoteMarks(
    store,
    deviceId: id,
    now: () => clock = clock.add(const Duration(seconds: 1)),
  );

  setUp(() => store = MemoryFileStore());

  test('reads back what was set', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), pinned);
    await marks.set(path('lists/shop.md'), teal);

    expect((await marks.load()).value, {
      path('todo.md'): pinned,
      path('lists/shop.md'): teal,
    });
  });

  test('writes only its own device file', () async {
    await device('phone').set(path('todo.md'), pinned);
    await device('laptop').set(path('todo.md'), teal);

    expect(store.files.keys.map((p) => p.value), [
      '.truce/marks/phone.json',
      '.truce/marks/laptop.json',
    ]);
  });

  test('the newest mark of a note wins across devices', () async {
    await device('phone').set(path('todo.md'), pinned);
    await device('laptop').set(path('todo.md'), teal);
    await device('laptop').set(path('plan.md'), teal);
    await device('phone').set(path('plan.md'), pinned);

    expect((await device('phone').load()).value, {
      path('todo.md'): teal,
      path('plan.md'): pinned,
    });
  });

  test('an unmark beats an older mark from another device', () async {
    await device('phone').set(path('todo.md'), pinned);
    await device('laptop').set(path('todo.md'), NoteMark.none);

    expect((await device('phone').load()).value, isEmpty);
  });

  test('ignores files outside the marks folder and unreadable ones', () async {
    store
      ..put('notes.json', '{}')
      ..put('.truce/marks/old/phone.json', '{}')
      ..put('.truce/marks/.syncthing.truce-1.tmp', '{}')
      ..put('.truce/marks/broken.json', 'not json');
    await device('phone').set(path('todo.md'), pinned);

    expect((await device('phone').load()).value, {path('todo.md'): pinned});
  });

  test('keeps entries of a file it reads in part', () async {
    store.put('.truce/marks/laptop.json', '''
{
  "todo.md": {"pinned": true, "color": null, "changed": "2026-10-13T00:00:00Z"},
  "bad.md": {"pinned": "yes"},
  "/abs.md": {"pinned": true, "color": null, "changed": "2026-10-13T00:00:00Z"}
}''');

    expect((await device('phone').load()).value, {path('todo.md'): pinned});
  });

  test('reports store failures', () async {
    store.failWith = StoreError.accessDenied;

    expect((await device('phone').load()).error, StoreError.accessDenied);
    expect(
      (await device('phone').set(path('todo.md'), pinned)).error,
      StoreError.accessDenied,
    );
  });
}
