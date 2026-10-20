import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'markup_text.dart';
import 'shown_texts.dart';

/// Styles each text node as [marks] show it, by the markup its view
/// reads from the node's text; the selected nodes count as edited.
/// Records how each node shows in [texts], for its component to map
/// positions.
///
/// It follows the selection until [close]. Not in [dispose]: super_editor
/// disposes the phases of a layout it rebuilds, e.g. for a new stylesheet,
/// and goes on with the same phases in the new one.
final class MarksPhase extends SingleColumnLayoutStylePhase {
  MarksPhase({
    required this.marks,
    required this.viewOf,
    required this.texts,
    this._composer,
  }) {
    _composer?.selectionNotifier.addListener(markDirty);
  }

  final MarkStyle marks;

  /// The view a node shows; `null` for a node that shows none.
  final EditView? Function(String nodeId) viewOf;

  final ShownTexts texts;
  final DocumentComposer? _composer;

  /// Stops following the selection, once the editor is gone.
  void close() => _composer?.selectionNotifier.removeListener(markDirty);

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    texts.clear();
    final selected = _selectedNodes(document);
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final component in viewModel.componentViewModels)
          switch ((component, viewOf(component.nodeId))) {
            (final TextComponentViewModel text, final view?) => _styled(
              text,
              view,
              edited: selected.contains(component.nodeId),
            ),
            _ => component,
          },
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _styled(
    TextComponentViewModel component,
    EditView view, {
    required bool edited,
  }) {
    final source = component.text.toPlainText();
    final shown = marks.show(source, view.markupOf(source), edited: edited);
    texts.set(component.nodeId, shown);
    return (component.copy() as TextComponentViewModel)
      ..text = markupText(shown.text, shown.markup);
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
