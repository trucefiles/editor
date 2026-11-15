import 'package:truce_core/truce_core.dart' show findExtendedAutolinks;

/// A stretch of an event's text: plain, or a [link] it makes by what it
/// says.
typedef LinkPart = ({String text, Uri? link});

/// [text] in its plain stretches and the bare links it holds, as GitHub
/// Flavored Markdown finds them in a document's text (`www.` and scheme
/// urls, email addresses), in order.
List<LinkPart> linkParts(String text) {
  final found = findExtendedAutolinks(text, 0, text.length);
  final ends = [
    0,
    for (final link in found) ...[link.start, link.end],
  ];
  return [
    for (final (index, link) in found.indexed) ...[
      if (link.start > ends[2 * index])
        (text: text.substring(ends[2 * index], link.start), link: null),
      (
        text: text.substring(link.start, link.end),
        link: Uri.tryParse(link.destination),
      ),
    ],
    if (ends.last < text.length) (text: text.substring(ends.last), link: null),
  ];
}
