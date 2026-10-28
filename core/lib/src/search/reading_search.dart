import 'dart:async';

import 'package:pool/pool.dart';

import 'search_match.dart';
import 'text_search.dart';

/// A search that reads every item's text when it opens, in the
/// background, a few at a time, and keeps the texts only while it is
/// open. Texts changed meanwhile are not read again: a search lasts
/// seconds. Matches names at once and texts as they come.
final class ReadingSearch<Item> implements OpenSearch<Item> {
  /// Opens the search over [items] and starts reading.
  ReadingSearch(List<Searchable<Item>> items, {int readsAtOnce = 4})
    : _items = List.unmodifiable(items),
      _texts = List.filled(items.length, null) {
    final pool = Pool(readsAtOnce);
    _reads = Future.wait([
      for (final (index, item) in _items.indexed)
        pool.withResource(() => _read(index, item)),
    ]).whenComplete(pool.close);
  }

  final List<Searchable<Item>> _items;

  /// The texts read so far, by item.
  final List<SearchText?> _texts;

  late final Future<void> _reads;
  final _changes = StreamController<void>.broadcast();
  var _done = 0;
  var _closed = false;

  @override
  bool get complete => _done == _items.length;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  List<Item> find(String query) {
    final words = searchWords(query);
    final matches = [
      for (final (index, item) in _items.indexed)
        (item: item.item, match: matchOf(words, item, _texts[index])),
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
    _texts[index] = text;
    _done++;
    _changes.add(null);
  }

  @override
  Future<void> close() async {
    _closed = true;
    _texts.fillRange(0, _texts.length, null);
    await _changes.close();
    await _reads;
  }
}
