import 'package:flutter/material.dart';

import '../../common/floating_button_room.dart';
import 'file_grid.dart';

/// Cards in a grid: [leading] first, then [pinned] and [others] under a
/// "Pinned" and an [othersHeading] heading, then [footer]. Headings show
/// only if something is pinned. Only cards near the screen are built.
class FileSections extends StatelessWidget {
  const FileSections({
    required this.pinned,
    required this.others,
    required this.othersHeading,
    this.leading = const [],
    this.footer,
    super.key,
  });

  final List<Widget> leading;
  final List<Widget> pinned;
  final List<Widget> others;
  final String othersHeading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      // Pulls down even when the cards fit, to refresh.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, floatingButtonRoom),
          sliver: SliverMainAxisGroup(
            slivers: [
              _grid(leading),
              if (pinned.isNotEmpty) ...[
                const _Heading('Pinned'),
                _grid(pinned),
                if (others.isNotEmpty) _Heading(othersHeading),
              ],
              _grid(others),
              if (footer case final footer?) SliverToBoxAdapter(child: footer),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _grid(List<Widget> cards) =>
    fileGrid(cards.length, (index) => cards[index]);

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: FilesHeading(label));
}

/// A heading above a group of files.
class FilesHeading extends StatelessWidget {
  const FilesHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}
