import 'package:flutter/material.dart';

import 'note_grid.dart';

/// Cards in a grid: [leading] first, then [pinned] and [others] under a
/// "Pinned" and an "Others" heading. Headings show only if something is
/// pinned.
class NoteSections extends StatelessWidget {
  const NoteSections({
    required this.pinned,
    required this.others,
    this.leading = const [],
    super.key,
  });

  final List<Widget> leading;
  final List<Widget> pinned;
  final List<Widget> others;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
          sliver: SliverMainAxisGroup(
            slivers: [
              _grid(leading),
              if (pinned.isNotEmpty) ...[
                const _Heading('Pinned'),
                _grid(pinned),
                if (others.isNotEmpty) const _Heading('Others'),
              ],
              _grid(others),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _grid(List<Widget> cards) => SliverGrid(
    gridDelegate: noteGridDelegate,
    delegate: SliverChildListDelegate(cards),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    ),
  );
}
