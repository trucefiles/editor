import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'editor_gate.dart';
import 'markdown/markdown_edit_view.dart';
import 'read/read_view.dart';
import 'ui/document_image.dart';
import 'visual/image_insert.dart';
import 'visual/visual_edit_view.dart';

/// The open document in the mode its editor owner (behind [gate]) is in:
/// Visual edit, Markdown edit, or Read of [text], the edits as last kept.
/// Lists in Visual edit get Add item buttons at [addItems]; what the
/// editor asks of the user comes in [notices]. Links open with [onLink];
/// images show as [images] finds them, and Visual edit adds them as
/// [imageAdding] says (none if `null`); Markdown edit pastes text as
/// [pasted] gives it. The one place that picks the view of each mode;
/// each is built anew for its mode.
class DocumentEditor extends StatelessWidget {
  const DocumentEditor(
    this.gate, {
    required this.text,
    required this.notices,
    required this.addItems,
    required this.onLink,
    required this.images,
    this.imageAdding,
    this.pasted,
    this.autofocus = false,
    super.key,
  });

  final EditorGate gate;
  final String text;
  final Stream<EditorEvent> notices;
  final AddItemPlace addItems;
  final void Function(String url) onLink;
  final DocumentImageLookup images;
  final ImageAdding? imageAdding;
  final FutureOr<String> Function(String text)? pasted;

  /// Puts the caret into the document right away, e.g. a new one.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => switch (gate.state.mode) {
    EditMode.visual => VisualEditView(
      gate,
      key: const ValueKey(EditMode.visual),
      notices: notices,
      addItems: addItems,
      onLink: onLink,
      images: images,
      imageAdding: imageAdding,
      autofocus: autofocus,
    ),
    EditMode.markdown => MarkdownEditView(
      gate,
      key: const ValueKey(EditMode.markdown),
      onLink: onLink,
      pasted: pasted,
      autofocus: autofocus,
    ),
    EditMode.read => ReadView(
      text,
      key: const ValueKey(EditMode.read),
      onLink: onLink,
      images: images,
    ),
  };
}
