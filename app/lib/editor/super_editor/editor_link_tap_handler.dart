import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'marks/document_markup.dart';

/// Opens links tapped in the [editor] with [onLink]: with Ctrl (or Cmd)
/// held on any line, and with a plain tap if [tapOpens], on a line the
/// caret is not in. A tap on a link in the caret's line places the caret,
/// so the link can be edited.
class EditorLinkTapHandler extends ContentTapDelegate {
  EditorLinkTapHandler(
    this.editor, {
    required this.kindOf,
    required this.tapOpens,
    required this.onLink,
  });

  final Editor editor;

  /// The kind of the line a node shows.
  final LineKind Function(String nodeId) kindOf;
  final bool tapOpens;
  final void Function(String url) onLink;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) =>
      _opens(hoverPosition) && _linkAt(hoverPosition) != null
      ? SystemMouseCursors.click
      : null;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final position = details.documentLayout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    if (position == null || !_opens(position)) {
      return TapHandlingInstruction.continueHandling;
    }
    final url = _linkAt(position);
    if (url == null) return TapHandlingInstruction.continueHandling;
    onLink(url);
    return TapHandlingInstruction.halt;
  }

  bool _opens(DocumentPosition position) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) return true;
    return tapOpens &&
        editor.composer.selection?.extent.nodeId != position.nodeId;
  }

  String? _linkAt(DocumentPosition position) {
    final node = editor.document.getNodeById(position.nodeId);
    if (node is! TextNode) return null;
    if (position.nodePosition case TextNodePosition(:final offset)) {
      for (final span in nodeMarkup(node, kindOf(node.id))) {
        if (span.markup case LinkMarkup(:final url)
            when span.start <= offset && offset < span.end) {
          return url;
        }
      }
    }
    return null;
  }
}
