/// Kinds of links a tap in a document opens. Others (local files, relative
/// paths, app schemes) could run things the reader didn't expect.
const _openedSchemes = {'http', 'https', 'mailto'};

/// Opens [href], a link tapped in rendered Markdown, with [open] if it is
/// a web or mail link; else [hint] tells that it can't be opened.
Future<void> openMarkdownLink(
  String? href, {
  required Future<void> Function(Uri link) open,
  required void Function(String message) hint,
}) async {
  final link = href == null ? null : Uri.tryParse(href);
  if (link != null && _openedSchemes.contains(link.scheme.toLowerCase())) {
    await open(link);
  } else {
    hint("Can't open ${href ?? 'this link'}");
  }
}
