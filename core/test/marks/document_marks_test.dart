import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const amber = DocumentMark(color: 'amber');
  const teal = DocumentMark(color: 'teal');

  late MemoryFileStore store;
  var clock = DateTime.utc(2026, 10, 13);

  /// The marks as device [id] sees them; each write is a second later.
  DocumentMarks device(String id) => DocumentMarks(
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
    await marks.set(path('todo.md'), amber);
    await marks.set(path('lists/shop.md'), teal);

    expect((await marks.load()).value, {
      path('todo.md'): amber,
      path('lists/shop.md'): teal,
    });
  });

  test('marks set at the same time are all kept', () async {
    final marks = device('phone');
    final set = await Future.wait([
      marks.set(path('todo.md'), amber),
      marks.set(path('lists/shop.md'), teal),
    ]);

    expect(set, everyElement(isA<Ok<void, StoreError>>()));
    expect((await marks.load()).value, {
      path('todo.md'): amber,
      path('lists/shop.md'): teal,
    });
  });

  test('writes only its own device file', () async {
    await device('phone').set(path('todo.md'), amber);
    await device('laptop').set(path('todo.md'), teal);

    expect(store.files.keys.map((p) => p.value), [
      'todo.md',
      'plan.md',
      'lists/shop.md',
      '.truce/marks/phone.json',
      '.truce/marks/laptop.json',
    ]);
  });

  test('the newest mark of a document wins across devices', () async {
    await device('phone').set(path('todo.md'), amber);
    await device('laptop').set(path('todo.md'), teal);
    await device('laptop').set(path('plan.md'), teal);
    await device('phone').set(path('plan.md'), amber);

    expect((await device('phone').load()).value, {
      path('todo.md'): teal,
      path('plan.md'): amber,
    });
  });

  test('an unmark beats an older mark from another device', () async {
    await device('phone').set(path('todo.md'), amber);
    await device('laptop').set(path('todo.md'), DocumentMark.none);

    expect((await device('phone').load()).value, isEmpty);
  });

  test('remove drops the mark of a document', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), amber);
    await marks.set(path('plan.md'), teal);

    await marks.remove(path('todo.md'));

    expect((await marks.load()).value, {path('plan.md'): teal});
  });

  test('remove writes nothing if there is nothing to drop', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), amber);
    final before = store.files[path('.truce/marks/phone.json')]!.version;

    expect(await marks.remove(path('plan.md')), isA<Ok<void, StoreError>>());
    expect(store.files[path('.truce/marks/phone.json')]!.version, before);
  });

  test('each write drops the marks of gone documents', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), amber);
    await marks.set(path('lists/shop.md'), teal);
    // Deleted or renamed outside the app.
    store.files.remove(path('todo.md'));
    store.files.remove(path('lists/shop.md'));

    await marks.set(path('plan.md'), amber);

    expect(
      store.textOf('.truce/marks/phone.json'),
      allOf(contains('plan.md'), isNot(contains('todo.md'))),
    );
    expect(store.textOf('.truce/marks/phone.json'), isNot(contains('shop')));
  });

  test("never drops other devices' marks", () async {
    await device('laptop').set(path('todo.md'), amber);
    store.files.remove(path('todo.md'));

    await device('phone').set(path('plan.md'), teal);

    expect(store.textOf('.truce/marks/laptop.json'), contains('todo.md'));
  });

  test('ignores files outside the marks folder and unreadable ones', () async {
    store
      ..put('documents.json', '{}')
      ..put('.truce/marks/old/phone.json', '{}')
      ..put('.truce/marks/.syncthing.truce-1.tmp', '{}')
      ..put('.truce/marks/broken.json', 'not json');
    await device('phone').set(path('todo.md'), amber);

    expect((await device('phone').load()).value, {path('todo.md'): amber});
  });

  test('keeps entries of a file it reads in part', () async {
    store.put('.truce/marks/laptop.json', '''
{
  "todo.md": {"color": "amber", "changed": "2026-10-13T00:00:00Z"},
  "bad.md": {"color": 1},
  "/abs.md": {"color": "amber", "changed": "2026-10-13T00:00:00Z"}
}''');

    expect((await device('phone').load()).value, {path('todo.md'): amber});
  });

  test('never writes over its own file if it cannot read it', () async {
    store.put('.truce/marks/phone.json', 'not json');

    final set = await device('phone').set(path('todo.md'), amber);

    expect(set.error, StoreError.ioFailure);
    expect(store.textOf('.truce/marks/phone.json'), 'not json');
  });

  test('reports store failures', () async {
    store.failWith = StoreError.accessDenied;

    expect((await device('phone').load()).error, StoreError.accessDenied);
    expect(
      (await device('phone').set(path('todo.md'), amber)).error,
      StoreError.accessDenied,
    );
  });

  test(
    'a write keeps marks of documents in subfolders it cannot read',
    () async {
      final marks = device('phone');
      await marks.set(path('lists/shop.md'), teal);
      store.unreadableFolders.add(path('lists'));

      await marks.set(path('todo.md'), amber);
      store.unreadableFolders.clear();

      expect((await marks.load()).value, {
        path('lists/shop.md'): teal,
        path('todo.md'): amber,
      });
    },
  );
}
