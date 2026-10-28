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

    expect((await marks.load()).value.marks, {
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
    expect((await marks.load()).value.marks, {
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

  test('keeps the marks of each directory next to its documents', () async {
    await device('phone').set(path('lists/shop.md'), teal);

    expect(
      store.textOf('lists/.truce/marks/phone.json'),
      contains('"shop.md"'),
    );
    expect(store.textOf('.truce/marks/phone.json'), isNull);
  });

  test('ignores entries an older version kept for other directories, '
      'and drops them at the next write', () async {
    store.put('.truce/marks/phone.json', '''
{
  "lists/shop.md": {"color": "amber", "changed": "2026-10-13T00:00:00Z"},
  "todo.md": {"color": "teal", "changed": "2026-10-13T00:00:00Z"}
}''');

    expect((await device('phone').load()).value.marks, {path('todo.md'): teal});
    await device('phone').set(path('plan.md'), amber);
    expect(store.textOf('.truce/marks/phone.json'), isNot(contains('shop')));
  });

  test('a write lists only its own directory', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), amber);
    store.put('lists/deep/x.md', 'x');

    await marks.set(path('plan.md'), teal);

    expect(
      store.lastListed.map((p) => p.value),
      unorderedEquals(['todo.md', 'plan.md']),
    );
  });

  test('the newest mark of a document wins across devices', () async {
    await device('phone').set(path('todo.md'), amber);
    await device('laptop').set(path('todo.md'), teal);
    await device('laptop').set(path('plan.md'), teal);
    await device('phone').set(path('plan.md'), amber);

    expect((await device('phone').load()).value.marks, {
      path('todo.md'): teal,
      path('plan.md'): amber,
    });
  });

  test('an unmark beats an older mark from another device', () async {
    await device('phone').set(path('todo.md'), amber);
    await device('laptop').set(path('todo.md'), DocumentMark.none);

    expect((await device('phone').load()).value.marks, isEmpty);
  });

  test('remove drops the mark of a document', () async {
    final marks = device('phone');
    await marks.set(path('todo.md'), amber);
    await marks.set(path('plan.md'), teal);

    await marks.remove(path('todo.md'));

    expect((await marks.load()).value.marks, {path('plan.md'): teal});
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

  test('ignores files outside the marks folders and unreadable ones', () async {
    store
      ..put('documents.json', '{}')
      ..put('.truce/marks/old/phone.json', '{}')
      ..put('.git/.truce/marks/phone.json', '{"todo.md": {}}')
      ..put('.truce/marks/.syncthing.truce-1.tmp', '{}')
      ..put('.truce/marks/broken.json', 'not json');
    await device('phone').set(path('todo.md'), amber);

    expect((await device('phone').load()).value.marks, {
      path('todo.md'): amber,
    });
  });

  test('keeps entries of a file it reads in part', () async {
    store.put('.truce/marks/laptop.json', '''
{
  "todo.md": {"color": "amber", "changed": "2026-10-13T00:00:00Z"},
  "bad.md": {"color": 1},
  "/abs.md": {"color": "amber", "changed": "2026-10-13T00:00:00Z"}
}''');

    expect((await device('phone').load()).value.marks, {
      path('todo.md'): amber,
    });
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

  test('a write keeps every mark of a directory it cannot list', () async {
    final marks = device('phone');
    await marks.set(path('lists/shop.md'), teal);
    store.unreadableFolders.add(path('lists'));

    await marks.set(path('lists/other.md'), amber);
    store.unreadableFolders.clear();

    expect((await marks.load()).value.marks, {
      path('lists/shop.md'): teal,
      path('lists/other.md'): amber,
    });
  });

  group('reading again', () {
    test('reads only the marks files that are new or changed', () async {
      await device('phone').set(path('todo.md'), amber);
      await device('laptop').set(path('lists/shop.md'), teal);
      final known = (await device('phone').load()).value;
      await device('laptop').set(path('lists/shop.md'), amber);
      store.reads.clear();

      final again = (await device('phone').load(known: known)).value;

      expect(store.reads, [path('lists/.truce/marks/laptop.json')]);
      expect(again.marks, {
        path('todo.md'): amber,
        path('lists/shop.md'): amber,
      });
    });

    test('leaves out marks files that are gone', () async {
      await device('phone').set(path('todo.md'), amber);
      final known = (await device('phone').load()).value;
      store.files.remove(path('.truce/marks/phone.json'));

      final again = (await device('phone').load(known: known)).value;

      expect(again.marks, isEmpty);
    });

    test('reloads the files asked, and only those', () async {
      await device('phone').set(path('todo.md'), amber);
      await device('laptop').set(path('plan.md'), teal);
      final known = (await device('phone').load()).value;
      await device('laptop').set(path('plan.md'), amber);
      store
        ..files.remove(path('.truce/marks/phone.json'))
        ..reads.clear();

      final again = await device('phone').reload(known, {
        path('.truce/marks/laptop.json'),
        path('.truce/marks/phone.json'),
        path('plan.md'),
      });

      expect(
        store.reads,
        unorderedEquals([
          path('.truce/marks/laptop.json'),
          path('.truce/marks/phone.json'),
        ]),
      );
      expect(again.marks, {path('plan.md'): amber});
    });

    test('a reload keeps what it knew of a file it cannot read now', () async {
      await device('phone').set(path('todo.md'), amber);
      final known = (await device('phone').load()).value;
      store.failWith = StoreError.accessDenied;

      final again = await device('phone')
          .reload(known, {path('.truce/marks/phone.json')});

      expect(again.marks, {path('todo.md'): amber});
    });
  });
}
