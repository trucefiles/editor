import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditKey;

import '../visual_actions.dart';

/// The toolbar of Visual edit: outdent and indent the caret's item (each
/// only where it can), format the selected text, make it a heading, a
/// list of a kind or a quote, and break the line within its block. Each
/// button does what [actions] says, then [onDone]. A bar at the bottom
/// of the screen: its buttons stay clear of the system's bottom edge
/// (e.g. Android's gesture line), its color goes under it.
class FormatToolbar extends StatelessWidget {
  const FormatToolbar(this.actions, {required this.onDone, super.key});

  final VisualActions actions;

  /// A button did its job: the editor takes the keyboard again.
  final VoidCallback onDone;

  static const _keys = [
    (EditKey.bold, Icons.format_bold, 'Bold (Ctrl+B)'),
    (EditKey.italic, Icons.format_italic, 'Italic (Ctrl+I)'),
    (EditKey.link, Icons.link, 'Link (Ctrl+K)'),
  ];

  static const _lists = [
    (EditKey.checklist, Icons.checklist, 'Checklist (Ctrl+Shift+9)'),
    (
      EditKey.bullet,
      Icons.format_list_bulleted,
      'Bulleted list (Ctrl+Shift+8)',
    ),
    (
      EditKey.numbered,
      Icons.format_list_numbered,
      'Numbered list (Ctrl+Shift+7)',
    ),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _button(
              Icons.format_indent_decrease,
              'Outdent (Shift+Tab)',
              actions.canOutdentHere
                  ? () => actions.press(EditKey.shiftTab)
                  : null,
            ),
            _button(
              Icons.format_indent_increase,
              'Indent (Tab)',
              actions.canIndentHere ? () => actions.press(EditKey.tab) : null,
            ),
            for (final (key, icon, label) in _keys)
              _button(icon, label, () => actions.press(key)),
            _button(Icons.title, 'Heading', actions.heading),
            for (final (key, icon, label) in _lists)
              _button(icon, label, () => actions.press(key)),
            _button(Icons.format_quote, 'Quote', actions.quote),
            _button(
              Icons.keyboard_return,
              'Line break (Shift+Enter)',
              () => actions.press(EditKey.shiftEnter),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _button(IconData icon, String label, VoidCallback? action) =>
      IconButton(
        tooltip: label,
        icon: Icon(icon),
        onPressed: switch (action) {
          final action? => () {
            action();
            onDone();
          },
          null => null,
        },
      );
}
