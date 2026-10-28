import 'dart:async';

import 'package:pool/pool.dart';

import 'search_match.dart';
import 'text_search.dart';

/// A search that reads every item's text when it opens, in the
/// background, a few at a time, and keeps the texts only while it is
/// open. Texts changed meanwhile are not read again: a search lasts
/// seconds. Matches names at once and texts as they come; tells of new
/// texts at most once per [changesEvery], and at once when complete.
final class ReadingSearch<Item> implements OpenSearch<Item> {
  /// Opens the search over [items] and starts reading.
  ReadingSearch(
    List<Searchable<Item>> items, {
    int readsAtOnce = 4,
    this.changesEvery = const Duration(milliseconds: 150),
  }) : _items = List.unmodifiable(items),
       _haystacks = [for (final item in items) haystackOf(item.names, null)] {
    final pool = Pool(readsAtOnce);
    _reads = Future.wait([
      for (final (index, item) in _items.indexed)
        pool.withResource(() => _read(index, item)),
    ]).whenComplete(pool.close);
  }

  final Duration changesEvery;

  final List<Searchable<Item>> _items;

  /// What each item is compared with; its text in it once read.
  final List<SearchHaystack> _haystacks;

  late final Future<void> _reads;
  final _changes = StreamController<void>.broadcast();
  Timer? _toldSoon;
  var _done = 0;
  var _closed = false;

  @override
  bool get complete => _done == _items.length;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  List<Item> find(String query) {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    final matches = [
      for (final (index, item) in _items.indexed)
        (item: item.item, match: matchOf(words, _haystacks[index])),
    ];
    return [
      for (final best in [SearchMatch.named, SearchMatch.inText])
        for (final (:item, :match) in matches)
          if (match == best) item,
    ];
  }

  Future<void> _read(int index, Searchable<Item> item) async {
    if (_closed) return;
    final text = await item.read();
    if (_closed) return;
    _haystacks[index] = haystackOf(item.names, text);
    _done++;
    _tell();
  }

  /// Tells of new texts: at once when complete, else once the time to
  /// gather more is up.
  void _tell() {
    if (complete) {
      _toldSoon?.cancel();
      _toldSoon = null;
      _changes.add(null);
    } else {
      _toldSoon ??= Timer(changesEvery, () {
        _toldSoon = null;
        if (!_closed) _changes.add(null);
      });
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _toldSoon?.cancel();
    _haystacks.fillRange(0, _haystacks.length, (named: '', all: ''));
    await _changes.close();
    await _reads;
  }
}
