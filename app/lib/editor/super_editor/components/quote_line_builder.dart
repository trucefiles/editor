import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Builds paragraphs as [ParagraphComponentBuilder] does, a quote with a
/// bar on its left, so it stands apart from the text around it.
class QuoteLineBuilder implements ComponentBuilder {
  const QuoteLineBuilder();

  static const _paragraphs = ParagraphComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => _paragraphs.createViewModel(document, node);

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel case final ParagraphComponentViewModel paragraph
        when paragraph.blockType == blockquoteAttribution) {
      return _QuoteLine(key: componentContext.componentKey, paragraph);
    }
    return _paragraphs.createComponent(componentContext, componentViewModel);
  }
}

/// A quote's paragraph with a bar on its left; positions and text pass
/// through to the paragraph.
class _QuoteLine extends StatefulWidget {
  const _QuoteLine(this.viewModel, {super.key});

  final ParagraphComponentViewModel viewModel;

  @override
  State<_QuoteLine> createState() => _QuoteLineState();
}

class _QuoteLineState extends State<_QuoteLine>
    with ProxyDocumentComponent<_QuoteLine>, ProxyTextComposable {
  final _paragraphKey = GlobalKey();

  @override
  GlobalKey get childDocumentComponentKey => _paragraphKey;

  @override
  TextComposable get childTextComposable =>
      _paragraphKey.currentState! as TextComposable;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: ParagraphComponent(
          key: _paragraphKey,
          viewModel: widget.viewModel,
        ),
      ),
      // Takes no hits: anything hit over a line keeps super_editor from
      // placing the caret there.
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 3,
        child: IgnorePointer(
          child: ColoredBox(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    ],
  );
}
