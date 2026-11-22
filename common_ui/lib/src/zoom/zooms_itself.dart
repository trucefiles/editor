import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as a view that zooms itself (e.g. a picture): a pinch
/// or wheel turn on it is its own, so a zoom gesture further up, such as
/// one for the text size, leaves it alone ([zoomsItselfAt]).
class ZoomsItself extends StatelessWidget {
  const ZoomsItself({required this.child, super.key});

  final Widget child;

  static const _mark = Object();

  @override
  Widget build(BuildContext context) => MetaData(metaData: _mark, child: child);
}

/// Whether a pointer at [position] in the view [viewId] is on a
/// [ZoomsItself].
bool zoomsItselfAt(Offset position, {required int viewId}) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, position, viewId);
  return result.path.any(
    (entry) => switch (entry.target) {
      RenderMetaData(:final metaData) => identical(metaData, ZoomsItself._mark),
      _ => false,
    },
  );
}
