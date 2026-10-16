import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

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

  setUp(
    () => store = MemoryFileStore()
      ..put('todo.md', 'todo')
      ..put('plan.md', 'plan')
      ..put('lists/shop.md', 'shop'),
  );

  test('reads back what was set', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), pinned);
    await marks.set(path('lists/shop.md'), teal);

    expect((await marks.load()).value, {
      path('todo.md'): pinned,
      path('lists/shop.md'): teal,
    });
  });

  test('marks set at the same time are all kept', () async {
    final marks = device('phone');
    final set = await Future.wait([
      marks.set(path('todo.md'), pinned),
      marks.set(path('lists/shop.md'), teal),
    ]);

    expect(set, everyElement(isA<Ok<void, StoreError>>()));
    expect((await marks.load()).value, {
      path('todo.md'): pinned,
      path('lists/shop.md'): teal,
    });
  });

  test('writes only its own device file', () async {
    await device('phone').set(path('todo.md'), pinned);
    await device('laptop').set(path('todo.md'), teal);

    expect(store.files.keys.map((p) => p.value), [
      'todo.md',
      'plan.md',
      'lists/shop.md',
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

  test('keeps whether a note shows a Done section', () async {
    const noDone = NoteMark(doneSection: false);
    await device('phone').set(path('todo.md'), noDone);

    expect((await device('laptop').load()).value, {path('todo.md'): noDone});
  });

  test('remove drops the mark of a note', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), pinned);
    await marks.set(path('plan.md'), teal);

    await marks.remove(path('todo.md'));

    expect((await marks.load()).value, {path('plan.md'): teal});
  });

  test('remove writes nothing if there is nothing to drop', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), pinned);
    final before = store.files[path('.truce/marks/phone.json')]!.version;

    expect(await marks.remove(path('plan.md')), isA<Ok<void, StoreError>>());
    expect(store.files[path('.truce/marks/phone.json')]!.version, before);
  });

  test('each write drops the marks of gone notes', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), pinned);
    await marks.set(path('lists/shop.md'), teal);
    // Deleted or renamed outside the app.
    store.files.remove(path('todo.md'));
    store.files.remove(path('lists/shop.md'));

    await marks.set(path('plan.md'), pinned);

    expect(
      store.textOf('.truce/marks/phone.json'),
      allOf(contains('plan.md'), isNot(contains('todo.md'))),
    );
    expect(store.textOf('.truce/marks/phone.json'), isNot(contains('shop')));
  });

  test("never drops other devices' marks", () async {
    await device('laptop').set(path('todo.md'), pinned);
    store.files.remove(path('todo.md'));

    await device('phone').set(path('plan.md'), teal);

    expect(store.textOf('.truce/marks/laptop.json'), contains('todo.md'));
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

  test('never writes over its own file if it cannot read it', () async {
    store.put('.truce/marks/phone.json', 'not json');

    final set = await device('phone').set(path('todo.md'), pinned);

    expect(set.error, StoreError.ioFailure);
    expect(store.textOf('.truce/marks/phone.json'), 'not json');
  });

  test('reports store failures', () async {
    store.failWith = StoreError.accessDenied;

    expect((await device('phone').load()).error, StoreError.accessDenied);
    expect(
      (await device('phone').set(path('todo.md'), pinned)).error,
      StoreError.accessDenied,
    );
  });

  test('a write keeps marks of notes in subfolders it cannot read', () async {
    final marks = device('phone');
    await marks.set(path('lists/shop.md'), teal);
    store.unreadableFolders.add(path('lists'));

    await marks.set(path('todo.md'), pinned);
    store.unreadableFolders.clear();

    expect((await marks.load()).value, {
      path('lists/shop.md'): teal,
      path('todo.md'): pinned,
    });
  });
}
