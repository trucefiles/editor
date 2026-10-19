import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'document_markup.dart';
import 'markup_text.dart';
import 'visual_lines.dart';

/// Styles each line by its Markdown, its marks dimmed. With [visual]
/// lines, it hides the marks of every line outside the selection and
/// records how those lines show there; the selected lines keep every
/// character, so typing never touches a hidden mark.
final class MarksPhase extends SingleColumnLayoutStylePhase {
  MarksPhase({this.visual, DocumentComposer? composer}) : _composer = composer {
    _composer?.selectionNotifier.addListener(markDirty);
  }

  final VisualLines? visual;
  final DocumentComposer? _composer;

  @override
  void dispose() {
    _composer?.selectionNotifier.removeListener(markDirty);
    super.dispose();
  }

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    visual?.clear();
    final markup = documentMarkup(document);
    final selected = _selectedNodes(document);
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final component in viewModel.componentViewModels)
          switch ((component, markup[component.nodeId])) {
            (final TextComponentViewModel text, final spans?) => _styled(
              text,
              spans,
              hide: visual != null && !selected.contains(component.nodeId),
            ),
            _ => component,
          },
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _styled(
    TextComponentViewModel component,
    List<MarkupSpan> spans, {
    required bool hide,
  }) {
    final copy = component.copy() as TextComponentViewModel;
    final source = component.text.toPlainText();
    if (!hide) {
      copy.text = markupText(source, spans);
      return copy;
    }
    final line = VisualLine.of(source, spans);
    visual!.set(component.nodeId, line);
    copy.text = markupText(line.text, line.markup);
    return copy;
  }

  Set<String> _selectedNodes(Document document) {
    final selection = _composer?.selection;
    if (selection == null) return const {};
    return {
      for (final node in document.getNodesInside(
        selection.base,
        selection.extent,
      ))
        node.id,
    };
  }
}
