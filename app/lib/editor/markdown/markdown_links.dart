import 'package:flutter/material.dart';

import '../../common/snack.dart';

/// Kinds of links a tap in a document opens. Others (local files, relative
/// paths, app schemes) could run things the reader didn't expect.
const _openedSchemes = {'http', 'https', 'mailto'};

/// Opens [href], a link tapped in rendered Markdown, with [open] if it is
/// a web or mail link; else a hint says it can't be opened.
Future<void> openMarkdownLink(
  BuildContext context,
  String? href, {
  required Future<void> Function(Uri link) open,
}) async {
  final link = href == null ? null : Uri.tryParse(href);
  if (link != null && _openedSchemes.contains(link.scheme.toLowerCase())) {
    await open(link);
  } else {
    showSnack(context, "Can't open ${href ?? 'this link'}");
  }
}
