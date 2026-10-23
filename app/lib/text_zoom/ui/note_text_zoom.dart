import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../text_zoom_controller.dart';
import '../text_zoom_target.dart';
import 'text_zoom_scale.dart';

/// [child], note text, at the note text zoom instead of the app's.
class NoteTextZoom extends ConsumerWidget {
  const NoteTextZoom({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextZoomScale(
    zoom: ref.watch(textZoomProvider(TextZoomTarget.notes)),
    child: child,
  );
}
