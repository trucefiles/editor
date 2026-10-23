import 'package:flutter/widgets.dart';

/// [child] in the middle of a scroll view as tall as the space it is
/// given, at least: a pull to refresh reaches it even when it fits.
class FilledScrollView extends StatelessWidget {
  const FilledScrollView({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}
