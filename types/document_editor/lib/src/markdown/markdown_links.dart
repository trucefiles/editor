/// Kinds of links a tap in a document opens. Others (local files, relative
/// paths, app schemes) could run things the reader didn't expect.
const _openedSchemes = {'http', 'https', 'mailto'};

/// Opens [href], a link tapped in rendered Markdown, with [open] if it is
/// a web or mail link; one written as `www.` and a host without a scheme
/// opens as https, as GFM links such text by itself (a bare
/// `example.com` could be a file, as `notes.md` is). [hint] tells when it
/// can't be opened, or [open] found no app for it (`false`).
Future<void> openMarkdownLink(
  String? href, {
  required Future<bool> Function(Uri link) open,
  required void Function(String message) hint,
}) async {
  final link = href == null ? null : Uri.tryParse(_withWebScheme(href));
  if (link == null || !_openedSchemes.contains(link.scheme.toLowerCase())) {
    hint("Can't open ${href ?? 'this link'}");
  } else if (!await open(link)) {
    hint('No app could open $link');
  }
}

/// [href] with `https://` before it if it starts with `www.`.
String _withWebScheme(String href) =>
    href.toLowerCase().startsWith('www.') ? 'https://$href' : href;
