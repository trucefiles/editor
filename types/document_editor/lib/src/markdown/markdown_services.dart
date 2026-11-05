import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart' show AddItemPlace;

/// What Markdown views need from the app beyond the page's host: where
/// lists get Add item buttons ([addItems], as the setting changes), and
/// how a web or mail link opens ([openLink]: `false` if no app could).
final class MarkdownServices {
  const MarkdownServices({required this.addItems, required this.openLink});

  final ValueListenable<AddItemPlace> addItems;
  final Future<bool> Function(Uri link) openLink;
}
