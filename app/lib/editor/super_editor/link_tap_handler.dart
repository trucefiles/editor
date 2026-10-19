import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import 'marks/markup_text.dart';

/// Hands the url of a tapped link in [document] to [onLink].
class LinkTapHandler extends ContentTapDelegate {
  LinkTapHandler(this.document, {required this.onLink});

  final Document document;
  final void Function(String url) onLink;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) =>
      _linkAt(hoverPosition) == null ? null : SystemMouseCursors.click;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final position = details.documentLayout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    final url = position == null ? null : _linkAt(position);
    if (url == null) return TapHandlingInstruction.continueHandling;
    onLink(url);
    return TapHandlingInstruction.halt;
  }

  String? _linkAt(DocumentPosition position) =>
      switch ((document.getNodeById(position.nodeId), position.nodePosition)) {
        (final TextNode node, TextNodePosition(:final offset)) => linkAt(
          node.text,
          offset,
        ),
        _ => null,
      };
}
