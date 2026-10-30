import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// [lines] one below the other, each drawn by [row] around its text, and
/// selected as one text: a selection over several lines copies them
/// with a line break between each, blank lines included. Needs a
/// [SelectionArea] above it.
class SelectableLines extends StatefulWidget {
  const SelectableLines({required this.lines, required this.row, super.key});

  final List<String> lines;
  final Widget Function(int index, Widget text) row;

  @override
  State<SelectableLines> createState() => _SelectableLinesState();
}

/// Stands in for a blank line: Flutter registers no selectable for an
/// empty `Text`, so a blank line would be skipped by a selection and
/// copy without its line break. A zero-width space takes no room and is
/// removed again from the copied text.
const _blank = '\u200B';

class _SelectableLinesState extends State<SelectableLines> {
  final _selection = _LinesSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionContainer(
    delegate: _selection,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, line) in widget.lines.indexed)
          widget.row(index, Text(line.isEmpty ? _blank : line)),
      ],
    ),
  );
}

/// Joins the selected lines with line breaks; Flutter's own delegate
/// puts their texts back to back.
class _LinesSelection extends StaticSelectionContainerDelegate {
  @override
  SelectedContent? getSelectedContent() {
    final selected = [
      for (final line in selectables)
        ?line.getSelectedContent()?.plainText.replaceAll(_blank, ''),
    ];
    return selected.isEmpty
        ? null
        : SelectedContent(plainText: selected.join('\n'));
  }
}
