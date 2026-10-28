import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  /// An item named [name] whose text reads as [text] once [gate] (if
  /// any) completes; counts its reads in [reads].
  Searchable<String> item(
    String name, {
    String title = '',
    String text = '',
    List<String> names = const [],
    Future<void>? gate,
    List<String>? reads,
  }) => Searchable(
    name,
    names: [name, ...names],
    read: () async {
      reads?.add(name);
      await gate;
      return (title: title, text: text);
    },
  );

  Future<ReadingSearch<String>> opened(List<Searchable<String>> items) async {
    final search = ReadingSearch(items);
    addTearDown(search.close);
    await search.changes
        .firstWhere((_) => search.complete)
        .timeout(const Duration(seconds: 1), onTimeout: () {});
    return search;
  }

  test('finds items whose text holds every word, ignoring case', () async {
    final search = await opened([
      item('a.md', text: 'Buy Milk and bread'),
      item('b.md', text: 'milk only'),
      item('c.md', text: 'nothing'),
    ]);

    expect(search.find('milk BREAD'), ['a.md']);
    expect(search.find('milk'), ['a.md', 'b.md']);
  });

  test('names and titles match first, then the order kept', () async {
    final search = await opened([
      item('a.md', text: 'about work'),
      item('b.md', names: ['Work'], text: 'x'),
      item('c.md', title: 'Work plan', text: 'y'),
    ]);

    expect(search.find('work'), ['b.md', 'c.md', 'a.md']);
  });

  test('a folder name on the path matches', () async {
    final search = await opened([
      item('plan.md', names: ['Documents', 'work']),
      item('other.md', names: ['Documents', 'home']),
    ]);

    expect(search.find('work'), ['plan.md']);
  });

  test('nothing for a query without words', () async {
    final search = await opened([item('a.md', text: 'a')]);

    expect(search.find('  '), isEmpty);
  });

  test('matches names before the texts are read, texts as they come', () async {
    final gate = Completer<void>();
    final search = ReadingSearch([
      item('milk.md', text: 'x', gate: gate.future),
      item('b.md', text: 'milk', gate: gate.future),
    ]);
    addTearDown(search.close);

    expect(search.find('milk'), ['milk.md']);
    expect(search.complete, isFalse);

    gate.complete();
    await search.changes.firstWhere((_) => search.complete);

    expect(search.find('milk'), ['milk.md', 'b.md']);
  });

  test('reads each text once, a few at a time', () async {
    final gate = Completer<void>();
    final reads = <String>[];
    final search = ReadingSearch([
      for (var i = 0; i < 10; i++)
        item('$i.md', gate: gate.future, reads: reads),
    ], readsAtOnce: 3);
    addTearDown(search.close);
    await pumpEventQueue();

    expect(reads, hasLength(3));
    gate.complete();
    await search.changes.firstWhere((_) => search.complete);
    expect(reads, hasLength(10));
  });

  test('an item that cannot be read still matches by name', () async {
    final search = await opened([
      Searchable('a.md', names: ['a.md'], read: () async => null),
    ]);

    expect(search.complete, isTrue);
    expect(search.find('a'), ['a.md']);
  });

  test(
    'tells of new texts at most once a while, and at once when complete',
    () async {
      final gate = Completer<void>();
      final search = ReadingSearch([
        for (var i = 0; i < 9; i++) item('$i.md', text: 'milk'),
        item('last.md', text: 'milk', gate: gate.future),
      ], changesEvery: const Duration(hours: 1));
      addTearDown(search.close);
      var told = 0;
      search.changes.listen((_) => told++);
      await pumpEventQueue();

      expect(search.find('milk'), hasLength(9));
      expect(told, 0);

      gate.complete();
      await pumpEventQueue();
      expect(told, 1);
      expect(search.find('milk'), hasLength(10));
    },
  );

  test('stops reading once closed', () async {
    final gate = Completer<void>();
    final reads = <String>[];
    final search = ReadingSearch([
      for (var i = 0; i < 10; i++)
        item('$i.md', gate: gate.future, reads: reads),
    ], readsAtOnce: 2);
    await pumpEventQueue();

    final closed = search.close();
    gate.complete();
    await closed;

    expect(reads, hasLength(2));
  });
}
