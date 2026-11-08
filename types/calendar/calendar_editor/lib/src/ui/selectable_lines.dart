import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [child]'s texts, selected inside a selection area, copied one per
/// line. Flutter's own delegates join separate texts with nothing, so
/// lines would run together.
class SelectableLines extends StatefulWidget {
  const SelectableLines({required this.child, super.key});

  final Widget child;

  @override
  State<SelectableLines> createState() => _SelectableLinesState();
}

class _SelectableLinesState extends State<SelectableLines> {
  final _delegate = _LinesDelegate();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer(delegate: _delegate, child: widget.child);
}

/// Flutter's delegate for a fixed set of texts, the selected parts of
/// each copied on a line of its own.
class _LinesDelegate extends StaticSelectionContainerDelegate {
  @override
  SelectedContent? getSelectedContent() {
    final parts = [
      for (final selectable in selectables)
        if (selectable.getSelectedContent() case final SelectedContent part)
          part.plainText,
    ];
    return parts.isEmpty ? null : SelectedContent(plainText: parts.join('\n'));
  }
}
