import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/open_link.dart';
import '../common/snack.dart';

/// Kinds of links a tap in a note opens. Others (local files, relative
/// paths, app schemes) could run things the reader didn't expect.
const _openedSchemes = {'http', 'https', 'mailto'};

/// Opens [href], a link tapped in rendered Markdown, if it is a web or mail
/// link; else a hint says it can't be opened.
Future<void> openMarkdownLink(
  BuildContext context,
  WidgetRef ref,
  String? href,
) async {
  final link = href == null ? null : Uri.tryParse(href);
  if (link != null && _openedSchemes.contains(link.scheme.toLowerCase())) {
    await openLink(context, ref, link);
  } else {
    showSnack(context, "Can't open ${href ?? 'this link'}");
  }
}
