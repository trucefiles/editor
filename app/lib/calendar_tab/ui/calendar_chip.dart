import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import '../calendar_tab_controller.dart';

/// A calendar's chip in the Calendar tab: its color and title, picked
/// while its events show; a tap turns them on or off ([onShown]). A long
/// press, or a right click, offers to hide it from the tab ([onHide]).
/// One whose events can't be read shows greyed, saying so.
class CalendarChip extends StatefulWidget {
  const CalendarChip(
    this.calendar, {
    required this.color,
    required this.onShown,
    required this.onHide,
    super.key,
  });

  final OfferedCalendar calendar;
  final Color color;
  final ValueChanged<bool> onShown;
  final VoidCallback onHide;

  @override
  State<CalendarChip> createState() => _CalendarChipState();
}

class _CalendarChipState extends State<CalendarChip> {
  final _menu = MenuController();

  /// Opens the menu at [position], a point on the screen.
  void _showMenuAt(Offset position) {
    final box = context.findRenderObject()! as RenderBox;
    _menu.open(position: box.globalToLocal(position));
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    menuChildren: [
      MenuItemButton(
        // Takes the focus, so Esc closes the menu.
        autofocus: true,
        leadingIcon: const Icon(Icons.visibility_off_outlined),
        onPressed: widget.onHide,
        child: const Text(_hideLabel),
      ),
    ],
    // Screen readers offer the hide as an action of the chip.
    child: Semantics(
      customSemanticsActions: {_hide: widget.onHide},
      child: GestureDetector(
        onLongPressStart: (details) => _showMenuAt(details.globalPosition),
        onSecondaryTapUp: (details) => _showMenuAt(details.globalPosition),
        child: switch (widget.calendar) {
          // Its chip stays, so it can still be hidden.
          UnreadableCalendar(:final title) => Tooltip(
            message: "Its events can't be read",
            child: FilterChip(
              avatar: CalendarDot(widget.color),
              label: Text(title),
              onSelected: null,
            ),
          ),
          final calendar => FilterChip(
            avatar: CalendarDot(widget.color),
            label: Text(calendar.title),
            selected: calendar is ShownCalendar,
            onSelected: widget.onShown,
          ),
        },
      ),
    ),
  );
}

const _hideLabel = 'Hide from this tab';
const _hide = CustomSemanticsAction(label: _hideLabel);
