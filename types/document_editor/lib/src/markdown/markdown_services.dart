import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show AddItemPlace;
import 'package:truce_markdown_images/truce_markdown_images.dart';

import 'package:truce_images/truce_images.dart';

/// What Markdown views need from the app beyond the page's host: where
/// lists get Add item buttons ([addItems], as the setting changes), how
/// a web or mail link opens ([openLink]: `false` if no app could), each
/// folder's document images ([imagesOf]), and how pictures are picked
/// ([picking]; no Image button if `null`).
final class MarkdownServices {
  const MarkdownServices({
    required this.addItems,
    required this.openLink,
    required this.imagesOf,
    this.picking,
  });

  final ValueListenable<AddItemPlace> addItems;
  final Future<bool> Function(Uri link) openLink;
  final DocumentImageStore Function(FolderId folder) imagesOf;
  final ImagePicking? picking;
}
