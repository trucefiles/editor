import 'package:flutter/material.dart';

/// "Untitled" where the first line goes while the document is [empty]:
/// never saved, an empty document gets its name from the first line
/// typed. Lets every tap through to the editor below.
class EmptyNoteHint extends StatelessWidget {
  const EmptyNoteHint({required this.empty, required this.padding, super.key});

  final bool empty;

  /// Where the first line's text starts.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => empty
      ? IgnorePointer(
          child: Padding(
            padding: padding,
            child: Text(
              'Untitled',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.4, color: Theme.of(context).hintColor),
            ),
          ),
        )
      : const SizedBox.shrink();
}
