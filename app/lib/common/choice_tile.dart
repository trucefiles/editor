import 'package:flutter/material.dart';

import 'choice_dialog.dart';

/// A settings row that names a choice ([title]) and shows the one made
/// ([subtitle]); a tap asks for one of [choices] (each shown by
/// [labelOf], [current] marked) and tells [onChosen] the pick.
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.choices,
    required this.labelOf,
    required this.current,
    required this.onChosen,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<T> choices;
  final String Function(T choice) labelOf;
  final T current;
  final Future<void> Function(T choice) onChosen;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: () async {
      final chosen = await showChoiceDialog(
        context,
        title: title,
        choices: choices,
        labelOf: labelOf,
        current: current,
      );
      if (chosen case (final choice,)) await onChosen(choice);
    },
  );
}
