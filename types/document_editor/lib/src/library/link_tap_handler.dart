import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// Hands the url of a tapped link to [onLink], where [opens] lets a tap
/// open one; [linkAt] tells the url of the link at a position, if any.
class LinkTapHandler extends ContentTapDelegate {
  LinkTapHandler({
    required this.linkAt,
    required this.onLink,
    this.opens = _always,
  });

  final String? Function(DocumentPosition position) linkAt;
  final void Function(String url) onLink;
  final bool Function(DocumentPosition position) opens;

  static bool _always(DocumentPosition _) => true;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) =>
      _urlAt(hoverPosition) == null ? null : SystemMouseCursors.click;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final position = details.documentLayout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    final url = position == null ? null : _urlAt(position);
    if (url == null) return TapHandlingInstruction.continueHandling;
    onLink(url);
    return TapHandlingInstruction.halt;
  }

  String? _urlAt(DocumentPosition position) =>
      opens(position) ? linkAt(position) : null;
}

/// Whether a tap opens a link while editing: with Ctrl (or Cmd) held on
/// any line, and with a plain tap if [tapOpens], on a line the caret
/// ([caretNode]) is not in. A tap on a link in the caret's line places the
/// caret, so the link can be edited.
bool editingTapOpens(
  DocumentPosition position, {
  required bool tapOpens,
  required String? caretNode,
}) {
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isControlPressed || keyboard.isMetaPressed) return true;
  return tapOpens && caretNode != position.nodeId;
}
