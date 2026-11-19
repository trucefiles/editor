import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart' show AddItemPlace;

import '../visual/image_picking.dart';

/// What Markdown views need from the app beyond the page's host: where
/// lists get Add item buttons ([addItems], as the setting changes), how
/// a web or mail link opens ([openLink]: `false` if no app could), and
/// how pictures are picked ([picking]; no Image button if `null`).
final class MarkdownServices {
  const MarkdownServices({
    required this.addItems,
    required this.openLink,
    this.picking,
  });

  final ValueListenable<AddItemPlace> addItems;
  final Future<bool> Function(Uri link) openLink;
  final ImagePicking? picking;
}
