/// Kinds of links a tap in a document opens. Others (local files, relative
/// paths, app schemes) could run things the reader didn't expect.
const _openedSchemes = {'http', 'https', 'mailto'};

/// Opens [href], a link tapped in rendered Markdown, with [open] if it is
/// a web or mail link; [hint] tells when it can't be opened, or [open]
/// found no app for it (`false`).
Future<void> openMarkdownLink(
  String? href, {
  required Future<bool> Function(Uri link) open,
  required void Function(String message) hint,
}) async {
  final link = href == null ? null : Uri.tryParse(href);
  if (link == null || !_openedSchemes.contains(link.scheme.toLowerCase())) {
    hint("Can't open ${href ?? 'this link'}");
  } else if (!await open(link)) {
    hint('No app could open $link');
  }
}
