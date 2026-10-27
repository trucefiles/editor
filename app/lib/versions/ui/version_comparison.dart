import 'package:flutter/material.dart';

/// Two versions of a document shown side by side, or stacked on narrow
/// screens, for the user to pick one.
class VersionComparison extends StatelessWidget {
  const VersionComparison({
    required this.first,
    required this.second,
    super.key,
  });

  /// Below this width the versions are stacked instead of side by side.
  static const _sideBySideWidth = 700.0;

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Flex(
      direction: constraints.maxWidth >= _sideBySideWidth
          ? Axis.horizontal
          : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        const VerticalDivider(width: 1),
        Expanded(child: second),
      ],
    ),
  );
}
