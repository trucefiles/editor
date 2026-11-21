import 'package:flutter/material.dart';
import 'package:truce_files/truce_files.dart';

/// What a shown file's [state] asks the user to know: it is gone (with
/// [close]), or a new one could be kept nowhere (with [retry]).
List<Widget> shownStateBanners(
  ShownState state, {
  required VoidCallback close,
  required VoidCallback retry,
}) => switch (state) {
  ShownGone() => [
    MaterialBanner(
      leading: const Icon(Icons.delete_outline),
      content: const Text('This file was deleted, moved or renamed elsewhere.'),
      actions: [TextButton(onPressed: close, child: const Text('Close'))],
    ),
  ],
  WaitingNew(kept: NewKept.nowhere) => [
    MaterialBanner(
      leading: const Icon(Icons.error_outline),
      content: const Text(
        "The file couldn't be saved yet. Try again, or pick another folder.",
      ),
      actions: [TextButton(onPressed: retry, child: const Text('Try again'))],
    ),
  ],
  WaitingNew() || ShownListed() || ShownDropped() => const [],
};
