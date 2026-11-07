import 'dart:async';

import 'package:flutter/material.dart';

import '../calendar_editor_part.dart';

/// The calendar's name in the page's title, edited in place; with no
/// name, the name the standard's `NAME` gives it shows greyed, else
/// [hint] (the file's name). Each change names the
/// calendar; a change made elsewhere (an undo, a reload) shows here.
class CalendarNameField extends StatefulWidget {
  const CalendarNameField(this.part, {required this.hint, super.key});

  final CalendarEditorPart part;
  final String hint;

  @override
  State<CalendarNameField> createState() => _CalendarNameFieldState();
}

class _CalendarNameFieldState extends State<CalendarNameField> {
  late final _name = TextEditingController(text: _shown);
  late final StreamSubscription<void> _changes;

  /// The name the calendar has now.
  String get _shown => widget.part.owner.state.calendar?.name ?? '';

  @override
  void initState() {
    super.initState();
    _changes = widget.part.owner.changes.listen((_) {
      if (_name.text == _shown) return;
      _name.value = TextEditingValue(
        text: _shown,
        selection: TextSelection.collapsed(offset: _shown.length),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return TextField(
      controller: _name,
      style: style,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration.collapsed(
        hintText: switch (widget.part.owner.state.calendar?.head.standardName) {
          final standard? when standard.isNotEmpty => standard,
          _ => widget.hint,
        },
        hintStyle: style.copyWith(color: Theme.of(context).hintColor),
      ),
      onChanged: widget.part.rename,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}
