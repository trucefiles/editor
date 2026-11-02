import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../library/library_nodes.dart';
import '../row_looks.dart';
import '../visual_actions.dart';
import 'row_component.dart';

/// Builds a [RowComponent] for each row with text: its text inside the
/// frames its look shows it in; the rows of items offer [actions].
class RowBuilder implements ComponentBuilder {
  const RowBuilder(this.actions);

  final VisualActions actions;

  @override
  RowViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) return null;
    return RowViewModel(
      nodeId: node.id,
      look: lookOf(node),
      text: node.text,
      textDirection: getParagraphDirection(node.text.toPlainText()),
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) => switch (componentViewModel) {
    final RowViewModel row => RowComponent(
      key: componentContext.componentKey,
      viewModel: row,
      actions: actions,
    ),
    _ => null,
  };
}

/// The view model of a [RowComponent]: its text and [look].
class RowViewModel extends SingleColumnLayoutComponentViewModel
    with TextComponentViewModel {
  RowViewModel({
    required super.nodeId,
    required this.look,
    required this.text,
    required this.textStyleBuilder,
    required this.selectionColor,
    super.padding = EdgeInsets.zero,
    this.textDirection = TextDirection.ltr,
  }) : super(createdAt: null);

  /// A [TextLook] or [RawTextLook].
  final RowLook look;

  /// The blocks the row is in, outermost first.
  List<Frame> get frames => switch (look) {
    TextLook(:final frames) || RawTextLook(:final frames) => frames,
    _ => const [],
  };

  /// The item the row's text is right in, if any.
  ItemFrame? get item => frames.whereType<ItemFrame>().lastOrNull;

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
  RowViewModel copy() => internalCopy(
    RowViewModel(
      nodeId: nodeId,
      look: look,
      text: text,
      textStyleBuilder: textStyleBuilder,
      selectionColor: selectionColor,
    ),
  ) as RowViewModel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is RowViewModel &&
          textViewModelEquals(other) &&
          other.look == look;

  @override
  int get hashCode => super.hashCode ^ textViewModelHashCode ^ look.hashCode;
}
