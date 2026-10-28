import 'text_search.dart';

/// The words of [query], in lower case; empty if it has none.
List<String> searchWords(String query) => [
  for (final word in query.toLowerCase().split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

/// What a query is compared with for one item, in lower case, worked out
/// once: its [named] part (names and title) and [all] of it.
typedef SearchHaystack = ({String named, String all});

/// The haystack of an item with [names] and [text] (`null` while not
/// read).
SearchHaystack haystackOf(List<String> names, SearchText? text) {
  final named = [...names, ?text?.title].join('\n').toLowerCase();
  return (
    named: named,
    all: text == null ? named : '$named\n${text.text.toLowerCase()}',
  );
}

/// How [words] (at least one) match [haystack]: by names or title, by
/// the text only, or not at all.
SearchMatch matchOf(List<String> words, SearchHaystack haystack) =>
    !words.every(haystack.all.contains)
    ? SearchMatch.none
    : words.any(haystack.named.contains)
    ? SearchMatch.named
    : SearchMatch.inText;

/// How a query matches an item, best first.
enum SearchMatch { named, inText, none }
