import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import 'mapped_text_component.dart';
import 'visual_lines.dart';

/// Builds what [inner] builds for view models of type [T], wrapped in a
/// [MappedTextComponent], for text nodes [lines] may show formatted.
class MappedBuilder<T extends TextComponentViewModel>
    implements ComponentBuilder {
  const MappedBuilder(this.inner, this.lines);

  final ComponentBuilder inner;
  final VisualLines lines;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => inner.createViewModel(document, node);

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! T) return null;
    return MappedTextComponent(
      key: componentContext.componentKey,
      nodeId: componentViewModel.nodeId,
      lines: lines,
      child: (key) => inner.createComponent(
        SingleColumnDocumentComponentContext(
          context: componentContext.context,
          componentKey: key,
        ),
        componentViewModel,
      )!,
    );
  }
}
