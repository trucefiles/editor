import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show BlockKind, EditKey, FormatState, TextFormat;

import '../visual_actions.dart';

/// The toolbar of Visual edit: outdent and indent the caret's item (each
/// only where it can), format the selected text, make it a heading, a
/// list of a kind or a quote, add a separator, and break the line within
/// its block. Each button does what [actions] says, then [onDone]; all
/// are off while no caret shows, as they act at the caret. A format or
/// kind of block that is on where the caret is shows its button pressed,
/// as in other editors. A bar
/// at the bottom of the screen: its buttons stay clear of the system's
/// bottom edge (e.g. Android's gesture line), its color goes under it.
class FormatToolbar extends StatelessWidget {
  const FormatToolbar(this.actions, {required this.onDone, super.key});

  final VisualActions actions;

  /// A button did its job: the editor takes the keyboard again.
  final VoidCallback onDone;

  static final _keys = [
    (
      EditKey.bold,
      Icons.format_bold,
      'Bold (Ctrl+B)',
      (FormatState on) => on.formats.contains(TextFormat.strong),
    ),
    (
      EditKey.italic,
      Icons.format_italic,
      'Italic (Ctrl+I)',
      (FormatState on) => on.formats.contains(TextFormat.emphasis),
    ),
    (EditKey.link, Icons.link, 'Link (Ctrl+K)', (FormatState on) => on.link),
  ];

  static const _lists = [
    (
      EditKey.checklist,
      Icons.checklist,
      'Checklist (Ctrl+Shift+9)',
      BlockKind.checklist,
    ),
    (
      EditKey.bullet,
      Icons.format_list_bulleted,
      'Bulleted list (Ctrl+Shift+8)',
      BlockKind.bullets,
    ),
    (
      EditKey.numbered,
      Icons.format_list_numbered,
      'Numbered list (Ctrl+Shift+7)',
      BlockKind.numbers,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final on = actions.formatState;
    return Material(
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
              for (final (key, icon, label, isOn) in _keys)
                _button(
                  icon,
                  label,
                  () => actions.press(key),
                  selected: isOn(on),
                ),
              _button(
                Icons.title,
                'Heading',
                actions.heading,
                selected: on.blocks.contains(BlockKind.heading),
              ),
              for (final (key, icon, label, kind) in _lists)
                _button(
                  icon,
                  label,
                  () => actions.press(key),
                  selected: on.blocks.contains(kind),
                ),
              _button(
                Icons.format_quote,
                'Quote',
                actions.quote,
                selected: on.blocks.contains(BlockKind.quote),
              ),
              _button(Icons.horizontal_rule, 'Separator', actions.separator),
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
  }

  /// A button showing [selected] as pressed, on a tinted round.
  Widget _button(
    IconData icon,
    String label,
    VoidCallback? action, {
    bool selected = false,
  }) => Builder(
    builder: (context) => IconButton(
      tooltip: label,
      isSelected: selected,
      style: IconButton.styleFrom(backgroundColor: Colors.transparent).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
      ),
      icon: Icon(icon),
      onPressed: switch (action) {
        final action? when actions.hasCaret => () {
          action();
          onDone();
        },
        _ => null,
      },
    ),
  );
}
