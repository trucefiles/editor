/// Search over the texts of many items (e.g. documents), behind one
/// interface: how the texts are found (read when the search opens, or a
/// saved index) is each implementation's own business.
library;

/// One item to search: its [names] match from memory (e.g. its file
/// name and the folders it lies in), its text once [read].
final class Searchable<Item> {
  const Searchable(this.item, {required this.names, required this.read});

  final Item item;

  /// What matches without reading the item.
  final List<String> names;

  /// Its text and title as they are now; `null` if it can't be read.
  final Future<SearchText?> Function() read;
}

/// An item's text as a search sees it.
typedef SearchText = ({String title, String text});

/// A search while it is open: questions on it are answered from what it
/// knows so far, and it may learn more ([changes]) until it is
/// [complete].
abstract interface class OpenSearch<Item> {
  /// The items every word of [query] matches, ignoring case: in an item's
  /// names, title or text. Those it matches by names or title come
  /// first; otherwise the order the search opened with is kept. Nothing
  /// for a query without words.
  List<Item> find(String query);

  /// Whether every item's text is known.
  bool get complete;

  /// Tells each time the search knows more.
  Stream<void> get changes;

  /// Ends the search and drops what it holds.
  Future<void> close();
}

/// Opens a search over [items].
typedef OpenTextSearch<Item> = OpenSearch<Item> Function(
  List<Searchable<Item>> items,
);
