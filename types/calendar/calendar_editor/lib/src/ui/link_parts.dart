import 'package:truce_core/truce_core.dart' show findExtendedAutolinks;

/// A stretch of an event's text: plain, or a [link] it makes by what it
/// says.
typedef LinkPart = ({String text, Uri? link});

/// [text] in its plain stretches and the bare links it holds, as GitHub
/// Flavored Markdown finds them in a document's text (`www.` and scheme
/// urls, email addresses), in order.
List<LinkPart> linkParts(String text) {
  final links = findExtendedAutolinks(text, 0, text.length);
  // Where the plain text before each link starts, and after the last.
  final plainFrom = [0, ...links.map((link) => link.end)];
  return [
    for (final (index, link) in links.indexed) ...[
      ?_plain(text, plainFrom[index], link.start),
      (
        text: text.substring(link.start, link.end),
        link: Uri.tryParse(link.destination),
      ),
    ],
    ?_plain(text, plainFrom.last, text.length),
  ];
}

/// [text] from [from] to [to] as a plain part; `null` if empty.
LinkPart? _plain(String text, int from, int to) =>
    from < to ? (text: text.substring(from, to), link: null) : null;
