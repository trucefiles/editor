import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../note_nodes.dart';
import 'item_actions.dart';
import 'leaf_component.dart';

/// Builds a [LeafComponent] for each text node: its text inside the
/// frames it shows in (see [framesKey]). With [actions], the rows of
/// items offer them.
class LeafBuilder implements ComponentBuilder {
  const LeafBuilder({this.actions});

  final ItemActions? actions;

  @override
  LeafViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) return null;
    final text = node.text.toPlainText();
    return LeafViewModel(
      nodeId: node.id,
      frames: node.getMetadataValue(framesKey) as List<Frame>? ?? const [],
      text: node.text,
      textDirection: getParagraphDirection(text),
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) => switch (componentViewModel) {
    final LeafViewModel leaf => LeafComponent(
      key: componentContext.componentKey,
      viewModel: leaf,
      actions: actions,
    ),
    _ => null,
  };
}

/// The view model of a [LeafComponent]: its text and the [frames] it
/// shows inside, outermost first.
class LeafViewModel extends SingleColumnLayoutComponentViewModel
    with TextComponentViewModel {
  LeafViewModel({
    required super.nodeId,
    required this.frames,
    required this.text,
    required this.textStyleBuilder,
    required this.selectionColor,
    super.padding = EdgeInsets.zero,
    this.textDirection = TextDirection.ltr,
  }) : super(createdAt: null);

  final List<Frame> frames;

  @override
  AttributedText text;
  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  InlineWidgetBuilderChain inlineWidgetBuilders = const [];
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment = TextAlign.left;
  @override
  int? maxLines;
  @override
  TextOverflow overflow = TextOverflow.clip;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty = false;

  @override
  LeafViewModel copy() => internalCopy(
    LeafViewModel(
      nodeId: nodeId,
      frames: frames,
      text: text,
      textStyleBuilder: textStyleBuilder,
      selectionColor: selectionColor,
    ),
  ) as LeafViewModel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is LeafViewModel &&
          textViewModelEquals(other) &&
          _frames.equals(other.frames, frames);

  @override
  int get hashCode =>
      super.hashCode ^ textViewModelHashCode ^ _frames.hash(frames);
}

const _frames = ListEquality<Frame>();
