import 'text_search.dart';

/// The words of [query], in lower case; empty if it has none.
List<String> searchWords(String query) => [
  for (final word in query.toLowerCase().split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

/// How [words] match [item], whose text is [text] (`null` while not
/// read): by names or title, by its text only, or not at all.
SearchMatch matchOf<Item>(
  List<String> words,
  Searchable<Item> item,
  SearchText? text,
) {
  final named = [...item.names, ?text?.title].join('\n').toLowerCase();
  final all = '$named\n${text?.text.toLowerCase() ?? ''}';
  if (words.isEmpty || !words.every(all.contains)) return SearchMatch.none;
  return words.any(named.contains) ? SearchMatch.named : SearchMatch.inText;
}

/// How a query matches an item, best first.
enum SearchMatch { named, inText, none }
